import Foundation
import IOKit
import ServiceManagement
import SwiftUI
import UserNotifications

enum KeepMode: String, Codable, CaseIterable {
    case always, timer, tasks

    var label: String {
        switch self {
        case .always: return "一直"
        case .timer: return "定时"
        case .tasks: return "任务结束"
        }
    }
}

/// User intent. Written by the app, enforced by the root daemon.
/// Keys must match DEFAULTS in daemon/vigild.py.
struct VigilConfig: Codable, Equatable {
    var enabled = false
    var keepMode = KeepMode.always
    var expiresAt: Double? = nil
    var timerMinutes = 60
    var watchProcesses = ["claude", "codex"]
    var idleGraceMinutes = 3
    var threshold = 20
    var onlyWhileCharging = false
    var autoEnableOnCharge = false
    var autoSuppressed = false
    var pauseWhenHot = true
    var batteryTempLimit = 45
    var chipTempLimit = 100
    var displayOffOnLidClose = false
    var notify = true

    enum CodingKeys: String, CodingKey {
        case enabled, threshold, notify
        case keepMode = "keep_mode"
        case expiresAt = "expires_at"
        case timerMinutes = "timer_minutes"
        case watchProcesses = "watch_processes"
        case idleGraceMinutes = "idle_grace_minutes"
        case onlyWhileCharging = "only_while_charging"
        case autoEnableOnCharge = "auto_enable_on_charge"
        case autoSuppressed = "auto_suppressed"
        case pauseWhenHot = "pause_when_hot"
        case batteryTempLimit = "battery_temp_limit"
        case chipTempLimit = "chip_temp_limit"
        case displayOffOnLidClose = "display_off_on_lid_close"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = VigilConfig()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        enabled = v(.enabled, d.enabled)
        keepMode = v(.keepMode, d.keepMode)
        expiresAt = try? c.decodeIfPresent(Double.self, forKey: .expiresAt)
        timerMinutes = v(.timerMinutes, d.timerMinutes)
        watchProcesses = v(.watchProcesses, d.watchProcesses)
        idleGraceMinutes = v(.idleGraceMinutes, d.idleGraceMinutes)
        threshold = v(.threshold, d.threshold)
        onlyWhileCharging = v(.onlyWhileCharging, d.onlyWhileCharging)
        autoEnableOnCharge = v(.autoEnableOnCharge, d.autoEnableOnCharge)
        autoSuppressed = v(.autoSuppressed, d.autoSuppressed)
        pauseWhenHot = v(.pauseWhenHot, d.pauseWhenHot)
        batteryTempLimit = v(.batteryTempLimit, d.batteryTempLimit)
        chipTempLimit = v(.chipTempLimit, d.chipTempLimit)
        displayOffOnLidClose = v(.displayOffOnLidClose, d.displayOffOnLidClose)
        notify = v(.notify, d.notify)
    }
}

/// What the daemon last reported.
struct DaemonState: Decodable {
    var hot = false
    var reason = ""
    var checkedAt: Double = 0
    var overrides: [Double] = []
    var lastBusyAt: Double = 0

    enum CodingKeys: String, CodingKey {
        case hot, reason, overrides
        case checkedAt = "checked_at"
        case lastBusyAt = "last_busy_at"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hot = (try? c.decodeIfPresent(Bool.self, forKey: .hot)) ?? false
        reason = (try? c.decodeIfPresent(String.self, forKey: .reason)) ?? ""
        checkedAt = (try? c.decodeIfPresent(Double.self, forKey: .checkedAt)) ?? 0
        overrides = (try? c.decodeIfPresent([Double].self, forKey: .overrides)) ?? []
        lastBusyAt = (try? c.decodeIfPresent(Double.self, forKey: .lastBusyAt)) ?? 0
    }
}

@MainActor
final class Store: ObservableObject {

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/vigil/config.json")
    static let daemonPlist = "/Library/LaunchDaemons/com.vigil.daemon.plist"
    static let stateURL = URL(fileURLWithPath: "/var/run/vigil.state.json")
    static let installedDaemonDir = "/usr/local/libexec/vigil"

    @Published var config = VigilConfig() { didSet { if config != oldValue { save() } } }
    @Published private(set) var isActive = false
    @Published private(set) var battery = SystemProbe.Battery(percent: nil, isCharging: false)
    @Published private(set) var sensors = Sensors.Reading()
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var lidClosed = false
    @Published private(set) var daemon = DaemonState()
    @Published private(set) var daemonInstalled = false
    @Published private(set) var daemonOutdated = false
    @Published private(set) var now = Date()
    @Published private(set) var isInstalling = false
    @Published var installError: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var timer: Timer?
    private var lastStatusKey = ""

    init() {
        load()
        refresh()
        lastStatusKey = statusKey
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: - Derived

    enum Status: Equatable {
        case notInstalled, off, waiting
        case active
        case paused(String)
    }

    var status: Status {
        if !daemonInstalled { return .notInstalled }
        if isActive { return .active }
        let wantsOn = config.enabled || (config.autoEnableOnCharge && battery.isCharging)
        if !wantsOn { return .off }
        let r = daemon.reason
        if r == "timer expired" { return .paused("定时结束") }
        if r == "agents idle" { return .paused("AI 任务已空闲") }
        if r == "not charging" { return .paused("未接电源") }
        if r.hasPrefix("battery ") { return .paused("电量低于 \(config.threshold)%") }
        if r.hasPrefix("hot: ") { return .paused("过热 · " + r.dropFirst(5)) }
        return .waiting
    }

    /// Apps known to rewrite power settings, by bundle ID.
    static let knownConflicts: [String: String] = [
        "com.netease.uuremote": "UU远程",
        "com.if.Amphetamine": "Amphetamine",
        "info.marcel-dierkes.KeepingYouAwake": "KeepingYouAwake",
        "com.nghialuong.lidless": "Lidless",
        "com.lihaoyun.Sleepless": "Sleepless",
        "com.youqu.todesk.mac": "ToDesk",
        "com.sunlogin.mac": "向日葵",
    ]

    /// Names of running apps that are known to fight over sleep settings.
    var conflictingApps: [String] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            app.bundleIdentifier.flatMap { Self.knownConflicts[$0] }
        }
        .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    var hasConflict: Bool {
        // One-off resets happen (macOS itself does it occasionally). A tool
        // fighting us flips it every minute, so require a pattern.
        daemonInstalled && daemon.overrides.filter { now.timeIntervalSince1970 - $0 < 1500 }.count >= 2
    }

    var daemonHealthy: Bool {
        daemonInstalled && now.timeIntervalSince1970 - daemon.checkedAt < 90
    }

    /// True when keep-awake is on only because the Mac is plugged in.
    var onBecauseCharging: Bool {
        !config.enabled && config.autoEnableOnCharge && battery.isCharging && !config.autoSuppressed
    }

    /// Secondary line under the hero title while active.
    var activeDetail: String {
        switch config.keepMode {
        case .always:
            return onBecauseCharging ? "接通电源自动开启" : "合盖不会休眠"
        case .timer:
            guard let exp = config.expiresAt else { return "合盖不会休眠" }
            let left = max(0, Int(exp - now.timeIntervalSince1970))
            let h = left / 3600, m = (left % 3600) / 60, s = left % 60
            return "剩余 " + (h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s))
        case .tasks:
            let idle = now.timeIntervalSince1970 - daemon.lastBusyAt
            if idle < 45 { return "AI 正在干活" }
            let left = max(0, Int(Double(config.idleGraceMinutes * 60) - idle))
            return String(format: "AI 已空闲 · %d:%02d 后休眠", left / 60, left % 60)
        }
    }

    // MARK: - Intents

    func setEnabled(_ on: Bool) {
        var c = config
        c.enabled = on
        // An explicit switch-off has to stick even while auto-on-charge would
        // turn it straight back on; it re-arms the next time power is plugged in.
        c.autoSuppressed = !on && c.autoEnableOnCharge && battery.isCharging
        c.expiresAt = (on && c.keepMode == .timer) ? Date().timeIntervalSince1970 + Double(c.timerMinutes * 60) : nil
        config = c
        if on { requestNotificationPermission() }
        refreshSoon()
    }

    func setKeepMode(_ mode: KeepMode) {
        var c = config
        c.keepMode = mode
        c.expiresAt = (c.enabled && mode == .timer) ? Date().timeIntervalSince1970 + Double(c.timerMinutes * 60) : nil
        config = c
    }

    func setTimerMinutes(_ minutes: Int) {
        var c = config
        c.timerMinutes = minutes
        if c.enabled, c.keepMode == .timer {
            c.expiresAt = Date().timeIntervalSince1970 + Double(minutes * 60)
        }
        config = c
    }

    func toggleWatched(_ process: String) {
        var c = config
        if let i = c.watchProcesses.firstIndex(of: process) {
            c.watchProcesses.remove(at: i)
        } else {
            c.watchProcesses.append(process)
        }
        config = c
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Vigil: launch at login failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func installDaemon() {
        isInstalling = true
        installError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Installer.install() }
            DispatchQueue.main.async {
                self.isInstalling = false
                if case .failure(let e) = result, (e as? Installer.Failure).map({ if case .cancelled = $0 { return false }; return true }) ?? true {
                    self.installError = e.localizedDescription
                }
                self.refresh()
            }
        }
    }

    func uninstallEverything() {
        do {
            try Installer.uninstall()
        } catch {
            if case Installer.Failure.cancelled = error { return }
            installError = error.localizedDescription
            return
        }
        try? FileManager.default.removeItem(at: Self.configURL.deletingLastPathComponent())
        try? SMAppService.mainApp.unregister()
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
            NSApplication.shared.terminate(nil)
        }
    }

    func quit() {
        var c = config
        c.enabled = false
        c.expiresAt = nil
        config = c
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Loop

    private func tick() {
        let wasClosed = lidClosed
        refresh()

        if lidClosed, !wasClosed, isActive, config.displayOffOnLidClose {
            // With SleepDisabled the panel can stay lit behind a closed lid.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, SystemProbe.lidClosed() else { return }
                SystemProbe.displaySleepNow()
            }
        }

        let key = statusKey
        if key != lastStatusKey {
            notifyTransition(from: lastStatusKey, to: status)
            lastStatusKey = key
        }
    }

    func refresh() {
        now = Date()
        let wasCharging = battery.isCharging
        battery = SystemProbe.battery()
        if wasCharging, !battery.isCharging, config.autoSuppressed {
            config.autoSuppressed = false   // unplugged: auto-on-charge re-arms
        }
        sensors = Sensors.read()
        thermal = SystemProbe.thermalState
        lidClosed = SystemProbe.lidClosed()
        isActive = SystemProbe.sleepDisabled()
        daemonInstalled = FileManager.default.fileExists(atPath: Self.daemonPlist)
        daemonOutdated = daemonInstalled && Self.installedDaemonDiffers()
        if let data = try? Data(contentsOf: Self.stateURL),
           let s = try? JSONDecoder().decode(DaemonState.self, from: data) {
            daemon = s
        }
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() }
    }

    // MARK: - Notifications

    private var statusKey: String {
        switch status {
        case .notInstalled: return "notInstalled"
        case .off: return "off"
        case .waiting: return "waiting"
        case .active: return "active"
        case .paused(let why): return "paused:" + why
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyTransition(from old: String, to new: Status) {
        guard config.notify, old == "active", case .paused(let why) = new else { return }
        let content = UNMutableNotificationContent()
        switch why {
        case "AI 任务已空闲":
            content.title = "AI 任务已完成"
            content.body = "Claude Code / Codex 已空闲 \(config.idleGraceMinutes) 分钟,Mac 恢复正常休眠。"
        case "定时结束":
            content.title = "守夜时间到了"
            content.body = "已恢复正常休眠。"
        default:
            content.title = "守夜已暂停"
            content.body = why + ",为保护电脑已恢复休眠。条件恢复后会自动继续。"
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - IO

    private static func installedDaemonDiffers() -> Bool {
        guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("daemon") else { return false }
        for file in ["vigild.py", "thermal.py", "vigil-sensors"] {
            guard let a = try? Data(contentsOf: bundled.appendingPathComponent(file)) else { continue }
            let b = try? Data(contentsOf: URL(fileURLWithPath: "\(installedDaemonDir)/\(file)"))
            if a != b { return true }
        }
        return false
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.configURL),
              let c = try? JSONDecoder().decode(VigilConfig.self, from: data) else { return }
        config = c
    }

    private func save() {
        let url = Self.configURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(config) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
