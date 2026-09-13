#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
vigild — the privileged half of Vigil.

Runs as root every 30 seconds via launchd. It reads the user's intent from
~/.config/vigil/config.json (written by the menu bar app, no password
needed) and enforces it on the system SleepDisabled flag, subject to guards:

  * auto-off timer
  * only while charging
  * low-battery cutoff
  * thermal pause (with hysteresis)
  * nobody logged in -> always restore normal sleep

Only this process ever calls `pmset`.
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
HYSTERESIS = 5.0  # 过热暂停后,需降到 (上限 - 5°C) 才恢复

DEFAULTS = {
    "enabled": False,
    "threshold": 20,
    "only_while_charging": False,
    "expires_at": None,
    "pause_when_hot": True,
    "temp_limit": 55,
    "auto_enable_on_charge": False,
}


def log(msg):
    try:
        with open(LOG_PATH, "a") as f:
            f.write("{}  {}\n".format(time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except OSError:
        pass


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout


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


def decide(cfg, state):
    """Return (want_awake, reason, hot_latched)."""
    hot_latched = state.get("hot", False)

    pct, charging = battery()

    enabled = cfg["enabled"] or (cfg["auto_enable_on_charge"] and charging)
    if not enabled:
        return False, "off", False

    expires = cfg.get("expires_at")
    if expires and time.time() > expires:
        return False, "timer expired", hot_latched

    if cfg["only_while_charging"] and not charging:
        return False, "not charging", hot_latched

    if not charging and pct is not None and pct < cfg["threshold"]:
        return False, "battery {}% < {}%".format(pct, cfg["threshold"]), hot_latched

    if cfg["pause_when_hot"]:
        limit = float(cfg["temp_limit"])
        if hot_latched:
            temp = thermal.component_temp()
            level = thermal.thermal_state()
            cooled = (temp is None or temp < limit - HYSTERESIS) and \
                     (level is None or level < thermal.SERIOUS)
            if not cooled:
                return False, "cooling down", True
            hot_latched = False
        else:
            too_hot, why = thermal.is_too_hot(limit)
            if too_hot:
                return False, "hot: " + why, True

    return True, "ok", hot_latched


def main():
    state = load_json(STATE_PATH, {"hot": False})

    if not console_user():
        if sleep_disabled():
            set_sleep_disabled(False)
            log("no console user -> sleep restored")
        return

    user = console_user()
    cfg = load_json("/Users/{}/.config/vigil/config.json".format(user), DEFAULTS)
    want, reason, hot = decide(cfg, state)

    if hot != state.get("hot"):
        log("thermal pause {}".format("ON" if hot else "OFF"))
    save_state({"hot": hot, "reason": reason, "checked_at": int(time.time())})

    current = sleep_disabled()
    if want != current:
        set_sleep_disabled(want)
        log("SleepDisabled {} -> {}  ({})".format(int(current), int(want), reason))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never crash-loop silently
        log("ERROR {}".format(exc))
        sys.exit(1)
