#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
vigild — the privileged half of Vigil.

Runs as root every 30 seconds via launchd. It reads the user's intent from
~/.config/vigil/config.json (written by the menu bar app, no password
needed) and enforces it on the system SleepDisabled flag, subject to guards:

  * keep mode: always / until a timer ends / while AI agents are busy
  * only while charging, low-battery cutoff
  * heat pause on battery or chip temperature, or system throttling,
    with hysteresis so it doesn't flap
  * nobody logged in -> always restore normal sleep

It also turns the built-in display off when the lid closes, and notices
when another program flips SleepDisabled behind its back.

Only this process ever changes SleepDisabled.
"""

import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thermal  # noqa: E402

LOG_PATH = "/var/log/vigil.log"
STATE_PATH = "/var/run/vigil.state.json"
HEAT_HYSTERESIS = 3.0     # °C cooler than the limit before resuming
HEAT_STRIKES = 2          # consecutive hot checks (~1 min) before pausing
BUSY_CPU = 3.0            # % CPU across an agent's process tree that counts as working

DEFAULTS = {
    "enabled": False,
    "keep_mode": "always",            # always | timer | tasks
    "expires_at": None,
    "watch_processes": ["claude", "codex"],
    "idle_grace_minutes": 3,
    "threshold": 20,
    "only_while_charging": False,
    "auto_enable_on_charge": False,
    "pause_when_hot": True,
    "battery_temp_limit": 45,
    "chip_temp_limit": 100,
    "display_off_on_lid_close": True,
}

STATE_DEFAULTS = {
    "hot": False,
    "heat_strikes": 0,
    "last_set": None,
    "overrides": [],
    "last_busy_at": 0,
    "lid_closed": False,
}


def log(msg):
    try:
        with open(LOG_PATH, "a") as f:
            f.write("{}  {}\n".format(time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except OSError:
        pass


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def console_user():
    user = run("stat", "-f", "%Su", "/dev/console").strip()
    return user if user and user != "root" else None


def load_json(path, defaults):
    data = dict(defaults)
    try:
        with open(path) as f:
            data.update(json.load(f))
    except (OSError, ValueError):
        pass
    return data


def save_state(state):
    try:
        with open(STATE_PATH, "w") as f:
            json.dump(state, f)
        os.chmod(STATE_PATH, 0o644)
    except OSError:
        pass


def battery():
    out = run("pmset", "-g", "batt")
    pct = None
    for tok in out.replace(";", " ").split():
        if tok.endswith("%") and tok[:-1].isdigit():
            pct = int(tok[:-1])
            break
    return pct, "AC Power" in out


def sleep_disabled():
    for line in run("pmset", "-g").splitlines():
        if "SleepDisabled" in line:
            return line.split()[-1] == "1"
    return False


def set_sleep_disabled(on):
    run("pmset", "-a", "disablesleep", "1" if on else "0")


def lid_closed():
    return '"AppleClamshellState" = Yes' in run("ioreg", "-r", "-k", "AppleClamshellState", "-d", "1")


def agents_busy(names):
    """
    True if any watched agent (e.g. `claude`, `codex`) or anything it spawned
    is using CPU. A process merely existing isn't enough: desktop apps keep
    an idle CLI around.
    """
    rows = []
    for line in run("ps", "-Ao", "pid=,ppid=,pcpu=,comm=").splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4:
            try:
                rows.append((int(parts[0]), int(parts[1]), float(parts[2]),
                             os.path.basename(parts[3])))
            except ValueError:
                continue

    children = {}
    for pid, ppid, _, _ in rows:
        children.setdefault(ppid, []).append(pid)
    cpu = {pid: c for pid, _, c, _ in rows}

    roots = [pid for pid, _, _, comm in rows if comm in names]
    total, seen, stack = 0.0, set(), list(roots)
    while stack:
        pid = stack.pop()
        if pid in seen:
            continue
        seen.add(pid)
        total += cpu.get(pid, 0.0)
        stack.extend(children.get(pid, []))
    return bool(roots) and total >= BUSY_CPU


def decide(cfg, state, now):
    """Return (want_awake, reason). Updates `state` in place."""
    pct, charging = battery()

    enabled = cfg["enabled"] or (cfg["auto_enable_on_charge"] and charging)
    if not enabled:
        state["hot"] = False
        return False, "off"

    mode = cfg["keep_mode"]
    if mode == "timer":
        expires = cfg.get("expires_at")
        if expires and now > expires:
            return False, "timer expired"
    elif mode == "tasks":
        if agents_busy(set(cfg["watch_processes"])):
            state["last_busy_at"] = now
        idle_for = now - state.get("last_busy_at", 0)
        if idle_for > cfg["idle_grace_minutes"] * 60:
            return False, "agents idle"

    if cfg["only_while_charging"] and not charging:
        return False, "not charging"

    if not charging and pct is not None and pct < cfg["threshold"]:
        return False, "battery {}% < {}%".format(pct, cfg["threshold"])

    if cfg["pause_when_hot"]:
        hot = state.get("hot", False)
        margin = HEAT_HYSTERESIS if hot else 0.0
        why = thermal.check(float(cfg["battery_temp_limit"]), float(cfg["chip_temp_limit"]), margin)
        if hot:
            if why:
                return False, "hot: " + why
            state.update(hot=False, heat_strikes=0)
            log("heat pause OFF")
        elif why:
            # Brief spikes are normal (a compile on a fanless Air hits 95°C+).
            state["heat_strikes"] = state.get("heat_strikes", 0) + 1
            if state["heat_strikes"] >= HEAT_STRIKES:
                state["hot"] = True
                log("heat pause ON: " + why)
                return False, "hot: " + why
        else:
            state["heat_strikes"] = 0
    else:
        state.update(hot=False, heat_strikes=0)

    return True, "ok"


def handle_lid(cfg, state, awake):
    closed = lid_closed()
    if closed and not state.get("lid_closed") and awake and cfg["display_off_on_lid_close"]:
        # With SleepDisabled the panel can stay lit behind a closed lid,
        # wasting power and trapping heat.
        run("pmset", "displaysleepnow")
        log("lid closed -> display off")
    state["lid_closed"] = closed


def main():
    now = time.time()
    state = load_json(STATE_PATH, STATE_DEFAULTS)
    state.pop("override_at", None)
    user = console_user()

    if not user:
        if sleep_disabled():
            set_sleep_disabled(False)
            log("no console user -> sleep restored")
        state.update(last_set=False, reason="no user", checked_at=int(now))
        save_state(state)
        return

    cfg = load_json("/Users/{}/.config/vigil/config.json".format(user), DEFAULTS)
    want, reason = decide(cfg, state, now)

    current = sleep_disabled()
    last_set = state.get("last_set")
    if last_set is not None and current != last_set:
        state["overrides"] = (state.get("overrides", []) + [int(now)])[-10:]
        pct, charging = battery()
        log("external change detected: SleepDisabled {} -> {}  (lid={} ac={} battery={}%)".format(
            int(last_set), int(current), lid_closed(), charging, pct))

    if want != current:
        set_sleep_disabled(want)
        log("SleepDisabled {} -> {}  ({})".format(int(current), int(want), reason))

    handle_lid(cfg, state, want)
    state.update(last_set=want, reason=reason, checked_at=int(now))
    save_state(state)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never crash-loop silently
        log("ERROR {}".format(exc))
        sys.exit(1)
