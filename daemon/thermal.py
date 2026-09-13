#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Thermal readings for Vigil.

Real die and battery temperatures come from the bundled `vigil-sensors`
helper (IOHIDEventSystem, same source as Stats / iStat Menus). Apple's own
thermal pressure level comes from NSProcessInfo via JXA. If the helper is
missing we fall back to the smart battery controller in IORegistry.
"""

import json
import os
import re
import subprocess

NOMINAL, FAIR, SERIOUS, CRITICAL = 0, 1, 2, 3
HELPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vigil-sensors")


def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def readings():
    """{"chip": °C|None, "battery": °C|None, "ssd": °C|None}"""
    if os.access(HELPER, os.X_OK):
        try:
            data = json.loads(_run([HELPER]) or "{}")
            return {k: data.get(k) for k in ("chip", "battery", "ssd")}
        except ValueError:
            pass
    m = re.search(r'"Temperature"\s*=\s*(\d+)', _run(["ioreg", "-r", "-n", "AppleSmartBattery"]))
    return {"chip": None, "battery": int(m.group(1)) / 100.0 if m else None, "ssd": None}


def thermal_state():
    out = _run(["osascript", "-l", "JavaScript", "-e",
                'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState']).strip()
    return int(out) if out.isdigit() else None


def check(battery_limit, chip_limit, margin=0.0):
    """
    Return a reason string if any guard is tripped, else "".

    `margin` lowers every limit; pass the hysteresis while cooling down so
    the Mac has to get properly cooler before we resume.
    """
    r = readings()
    level = thermal_state()
    if level is not None and level >= SERIOUS and margin == 0:
        return "系统开始降频"
    if level is not None and level >= SERIOUS:
        return "系统仍在降频"
    if r["battery"] is not None and r["battery"] > battery_limit - margin:
        return "电池 {:.0f}°C".format(r["battery"])
    if r["chip"] is not None and r["chip"] > chip_limit - margin:
        return "芯片 {:.0f}°C".format(r["chip"])
    return ""


if __name__ == "__main__":
    print("readings     :", readings())
    print("thermal state:", thermal_state())
    print("check(45,95) :", repr(check(45, 95)))
