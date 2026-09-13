#!/bin/bash
#
# Remove Vigil completely and restore normal sleep.
#
#   sudo ./uninstall.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "需要管理员权限:  sudo ./uninstall.sh" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:-$(stat -f '%Su' /dev/console)}"
USER_HOME="$(dscl . -read "/Users/$USER_NAME" NFSHomeDirectory | awk '{print $2}')"

pkill -x Vigil 2>/dev/null || true
launchctl bootout system/com.vigil.daemon 2>/dev/null || true
rm -f  /Library/LaunchDaemons/com.vigil.daemon.plist
rm -rf /usr/local/libexec/vigil
rm -rf /Applications/Vigil.app
rm -f  /var/run/vigil.state.json
rm -rf "$USER_HOME/.config/vigil"

pmset -a disablesleep 0

echo "✅ 已彻底卸载,休眠行为已恢复正常。"
