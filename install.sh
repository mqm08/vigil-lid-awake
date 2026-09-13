#!/bin/bash
#
# Install Vigil from source: the root daemon + the menu bar app.
# Most people should download Vigil.dmg from Releases instead.
#
#   sudo ./install.sh
#
# This is the only step that needs your password. After this,
# everything is controlled from the menu bar — no more sudo.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "需要管理员权限:  sudo ./install.sh" >&2
    exit 1
fi

cd "$(dirname "$0")"
USER_NAME="${SUDO_USER:-$(stat -f '%Su' /dev/console)}"
USER_HOME="$(dscl . -read "/Users/$USER_NAME" NFSHomeDirectory | awk '{print $2}')"

if [ ! -d build/Vigil.app ]; then
    echo "› 首次安装,正在编译…"
    sudo -u "$USER_NAME" ./build.sh
fi

echo "› 安装后台服务"
install -d -m 755 -o root -g wheel /usr/local/libexec/vigil
install -m 755 -o root -g wheel daemon/vigild.py  /usr/local/libexec/vigil/vigild.py
install -m 644 -o root -g wheel daemon/thermal.py /usr/local/libexec/vigil/thermal.py
install -m 755 -o root -g wheel build/vigil-sensors /usr/local/libexec/vigil/vigil-sensors

install -m 644 -o root -g wheel daemon/com.vigil.daemon.plist /Library/LaunchDaemons/com.vigil.daemon.plist
launchctl bootout system/com.vigil.daemon 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.vigil.daemon.plist

echo "› 安装应用到 /Applications"
pkill -x Vigil 2>/dev/null || true
rm -rf /Applications/Vigil.app
cp -R build/Vigil.app /Applications/Vigil.app
chown -R "$USER_NAME":admin /Applications/Vigil.app

CONFIG_DIR="$USER_HOME/.config/vigil"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"

echo "› 启动"
sudo -u "$USER_NAME" open /Applications/Vigil.app

echo
echo "✅ 守夜 Vigil 已安装。点菜单栏的 🌙 图标开始使用。"
