import Foundation
import ServiceManagement
import SwiftUI

/// User intent. Written by the app, enforced by the root daemon.
struct VigilConfig: Codable, Equatable {
    var enabled = false
    var threshold = 20
    var onlyWhileCharging = false
    var expiresAt: Double? = nil
    var durationMinutes: Int? = nil
    var pauseWhenHot = true
    var tempLimit = 55
    var autoEnableOnCharge = false

    enum CodingKeys: String, CodingKey {
        case enabled, threshold
        case onlyWhileCharging = "only_while_charging"
        case expiresAt = "expires_at"
        case durationMinutes = "duration_minutes"
        case pauseWhenHot = "pause_when_hot"
        case tempLimit = "temp_limit"
        case autoEnableOnCharge = "auto_enable_on_charge"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = VigilConfig()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        threshold = try c.decodeIfPresent(Int.self, forKey: .threshold) ?? d.threshold
        onlyWhileCharging = try c.decodeIfPresent(Bool.self, forKey: .onlyWhileCharging) ?? d.onlyWhileCharging
        expiresAt = try c.decodeIfPresent(Double.self, forKey: .expiresAt)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        pauseWhenHot = try c.decodeIfPresent(Bool.self, forKey: .pauseWhenHot) ?? d.pauseWhenHot
        tempLimit = try c.decodeIfPresent(Int.self, forKey: .tempLimit) ?? d.tempLimit
        autoEnableOnCharge = try c.decodeIfPresent(Bool.self, forKey: .autoEnableOnCharge) ?? d.autoEnableOnCharge
    }
}

/// What the daemon last reported.
struct DaemonState: Decodable {
    var hot = false
    var reason = ""
    var checkedAt: Double = 0

    enum CodingKeys: String, CodingKey {
        case hot, reason
        case checkedAt = "checked_at"
    }
}

@MainActor
final class Store: ObservableObject {

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/vigil/config.json")
    static let daemonPlist = "/Library/LaunchDaemons/com.vigil.daemon.plist"
    static let stateURL = URL(fileURLWithPath: "/var/run/vigil.state.json")

    @Published var config = VigilConfig() { didSet { if config != oldValue { save() } } }
    @Published private(set) var isActive = false
    @Published private(set) var battery = SystemProbe.Battery(percent: nil, isCharging: false)
    @Published private(set) var temperature: Double?
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var daemon = DaemonState()
    @Published private(set) var daemonInstalled = false
    @Published private(set) var now = Date()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var timer: Timer?

    init() {
        load()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Derived

    enum Status {
        case notInstalled, off, active, waiting
        case paused(String)
    }

    var status: Status {
        if !daemonInstalled { return .notInstalled }
        let wantsOn = config.enabled || (config.autoEnableOnCharge && battery.isCharging)
        if isActive { return .active }
        if !wantsOn { return .off }
        if let exp = config.expiresAt, exp < now.timeIntervalSince1970 { return .paused("时间到了") }
        if config.onlyWhileCharging && !battery.isCharging { return .paused("未接电源") }
        if !battery.isCharging, let p = battery.percent, p < config.threshold {
            return .paused("电量低于 \(config.threshold)%")
        }
        if daemon.hot { return .paused("正在降温") }
        return .waiting
    }

    var daemonHealthy: Bool {
        daemonInstalled && now.timeIntervalSince1970 - daemon.checkedAt < 90
    }

    var remaining: String? {
        guard config.enabled, let exp = config.expiresAt else { return nil }
        let left = Int(exp - now.timeIntervalSince1970)
        guard left > 0 else { return nil }
        let h = left / 3600, m = (left % 3600) / 60, s = left % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Intents

    func setEnabled(_ on: Bool) {
        var c = config
        c.enabled = on
        c.expiresAt = on ? c.durationMinutes.map { Date().timeIntervalSince1970 + Double($0 * 60) } : nil
        config = c
        refreshSoon()
    }

    func setDuration(_ minutes: Int?) {
        var c = config
        c.durationMinutes = minutes
        if c.enabled {
            c.expiresAt = minutes.map { Date().timeIntervalSince1970 + Double($0 * 60) }
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

    func quit() {
        var c = config
        c.enabled = false
        c.expiresAt = nil
        config = c
        NSApplication.shared.terminate(nil)
    }

    // MARK: - IO

    func refresh() {
        now = Date()
        battery = SystemProbe.battery()
        temperature = SystemProbe.temperature()
        thermal = SystemProbe.thermalState
        isActive = SystemProbe.sleepDisabled()
        daemonInstalled = FileManager.default.fileExists(atPath: Self.daemonPlist)
        if let data = try? Data(contentsOf: Self.stateURL),
           let s = try? JSONDecoder().decode(DaemonState.self, from: data) {
            daemon = s
        }
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() }
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
