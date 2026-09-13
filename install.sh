#!/bin/bash
#
# Install Vigil: the root daemon + the menu bar app.
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

cat > /Library/LaunchDaemons/com.vigil.daemon.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>             <string>com.vigil.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/usr/local/libexec/vigil/vigild.py</string>
    </array>
    <key>StartInterval</key>     <integer>30</integer>
    <key>RunAtLoad</key>         <true/>
    <key>StandardErrorPath</key> <string>/var/log/vigil.log</string>
</dict>
</plist>
PLIST
chown root:wheel /Library/LaunchDaemons/com.vigil.daemon.plist
chmod 644 /Library/LaunchDaemons/com.vigil.daemon.plist
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
