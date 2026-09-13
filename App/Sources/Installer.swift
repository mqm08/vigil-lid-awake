import Foundation

/// Installs / removes the privileged daemon using the standard macOS
/// administrator password dialog. The app itself never sees the password.
enum Installer {

    enum Failure: LocalizedError {
        case cancelled
        case script(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "已取消"
            case .script(let msg): return msg
            }
        }
    }

    private static var resources: String {
        Bundle.main.resourceURL!.appendingPathComponent("daemon").path
    }

    static func install() throws {
        let r = resources
        try runAsAdmin("""
        set -e
        install -d -m 755 -o root -g wheel /usr/local/libexec/vigil
        install -m 755 -o root -g wheel '\(r)/vigild.py'  /usr/local/libexec/vigil/vigild.py
        install -m 644 -o root -g wheel '\(r)/thermal.py' /usr/local/libexec/vigil/thermal.py
        install -m 644 -o root -g wheel '\(r)/com.vigil.daemon.plist' /Library/LaunchDaemons/com.vigil.daemon.plist
        launchctl bootout system/com.vigil.daemon 2>/dev/null || true
        launchctl bootstrap system /Library/LaunchDaemons/com.vigil.daemon.plist
        """)
    }

    static func uninstall() throws {
        try runAsAdmin("""
        launchctl bootout system/com.vigil.daemon 2>/dev/null || true
        rm -f /Library/LaunchDaemons/com.vigil.daemon.plist
        rm -rf /usr/local/libexec/vigil
        rm -f /var/run/vigil.state.json
        pmset -a disablesleep 0
        """)
    }

    private static func runAsAdmin(_ shell: String) throws {
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        do shell script "\(escaped)" with prompt "守夜需要安装后台服务来管理休眠设置。" with administrator privileges
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw Failure.script("无法创建安装脚本")
        }
        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 { throw Failure.cancelled }
            throw Failure.script(error[NSAppleScript.errorMessage] as? String ?? "安装失败")
        }
    }
}
