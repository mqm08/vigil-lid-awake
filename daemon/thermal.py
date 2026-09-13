#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Thermal readings for Vigil, using only what ships with macOS.

Three independent signals, no third-party dependencies:

  battery_temp()   real battery temperature in °C, via IORegistry
  component_temp() internal component temperature in °C, via IORegistry
  thermal_state()  Apple's own NSProcessInfo thermal pressure level (0-3)
"""

import re
import subprocess

# NSProcessInfoThermalState
NOMINAL, FAIR, SERIOUS, CRITICAL = 0, 1, 2, 3

STATE_LABELS = {
    NOMINAL: "正常",
    FAIR: "温热",
    SERIOUS: "偏热",
    CRITICAL: "过热",
}


def _ioreg_value(key):
    try:
        out = subprocess.run(
            ["ioreg", "-r", "-n", "AppleSmartBattery"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        m = re.search(r'"{}"\s*=\s*(-?\d+)'.format(key), out)
        return int(m.group(1)) if m else None
    except Exception:
        return None


def battery_temp():
    """电池温度 (°C),读不到返回 None"""
    raw = _ioreg_value("Temperature")
    return raw / 100.0 if raw is not None else None


def component_temp():
    """机身内部元件温度 (°C),读不到返回 None"""
    raw = _ioreg_value("VirtualTemperature")
    return raw / 100.0 if raw is not None else None


def thermal_state():
    """Apple 官方热压力等级 0-3,读不到返回 None"""
    try:
        out = subprocess.run(
            ["osascript", "-l", "JavaScript", "-e",
             'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState'],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        return int(out) if out.isdigit() else None
    except Exception:
        return None


def is_too_hot(temp_limit=55.0):
    """
    判断是否过热。返回 (是否过热, 原因描述)。

    两个独立条件,任一触发即算过热:
      1. 元件温度超过设定上限
      2. 系统热压力达到 serious 及以上
    """
    state = thermal_state()
    if state is not None and state >= SERIOUS:
        return True, "系统热压力 {}".format(STATE_LABELS.get(state, state))

    temp = component_temp()
    if temp is not None and temp > temp_limit:
        return True, "机身 {:.0f}°C 超过 {:.0f}°C".format(temp, temp_limit)

    return False, ""


def summary():
    """给界面显示用的温度摘要"""
    temp = component_temp()
    state = thermal_state()
    parts = []
    if temp is not None:
        parts.append("{:.0f}°C".format(temp))
    if state is not None:
        parts.append(STATE_LABELS.get(state, str(state)))
    return "  ·  ".join(parts) if parts else "温度未知"


if __name__ == "__main__":
    print("电池温度 :", battery_temp(), "°C")
    print("元件温度 :", component_temp(), "°C")
    print("热压力   :", thermal_state(), STATE_LABELS.get(thermal_state(), ""))
    print("过热判定 :", is_too_hot())
