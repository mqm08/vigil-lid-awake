import Foundation
import IOKit
import IOKit.ps

/// Read-only probes into the system. Nothing here needs elevated privileges.
enum SystemProbe {

    struct Battery {
        var percent: Int?
        var isCharging: Bool
    }

    static func battery() -> Battery {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return Battery(percent: nil, isCharging: false) }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let current = desc["Current Capacity"] as? Int
            let max = desc["Max Capacity"] as? Int
            let onAC = (desc["Power Source State"] as? String) == "AC Power"
            if let current, let max, max > 0 {
                return Battery(percent: current * 100 / max, isCharging: onAC)
            }
        }
        return Battery(percent: nil, isCharging: false)
    }

    /// Internal component temperature in °C, from the smart battery controller.
    static func temperature() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        for key in ["VirtualTemperature", "Temperature"] {
            if let raw = IORegistryEntryCreateCFProperty(service, key as CFString,
                                                         kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int {
                return Double(raw) / 100.0
            }
        }
        return nil
    }

    static var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    /// Whether the system SleepDisabled flag is currently set.
    static func sleepDisabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return false }
        task.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        for line in out.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(separator: " ").last.map { $0.hasSuffix("1") } ?? false
        }
        return false
    }
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "正常"
        case .fair: return "温热"
        case .serious: return "偏热"
        case .critical: return "过热"
        @unknown default: return "未知"
        }
    }
}
