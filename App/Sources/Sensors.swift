import Foundation

/// Apple Silicon temperature sensors, read through the IOHIDEventSystem.
///
/// These are the same sensors tools like Stats and iStat Menus use. No root
/// needed. The symbols are private but have been stable since the M1.
enum Sensors {

    struct Reading: Codable {
        /// Hottest CPU/GPU/SoC die sensor, °C.
        var chip: Double?
        /// Hottest battery gas-gauge sensor, °C.
        var battery: Double?
        /// SSD controller, °C.
        var ssd: Double?
    }

    static func read() -> Reading {
        var chip: [Double] = [], battery: [Double] = [], ssd: [Double] = []
        for (name, value) in all() {
            let n = name.lowercased()
            if n.contains("gas gauge") {
                battery.append(value)
            } else if n.contains("nand") {
                ssd.append(value)
            } else if n.contains("pacc") || n.contains("eacc") || n.contains("soc")
                        || n.contains("gpu") || n.contains("tdie") {
                chip.append(value)
            }
        }
        return Reading(chip: chip.max(), battery: battery.max(), ssd: ssd.max())
    }

    /// Every temperature sensor the system exposes, as (name, °C).
    static func all() -> [(String, Double)] {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue() else {
            return []
        }
        let matching = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary
        _ = IOHIDEventSystemClientSetMatching(client, matching)
        guard let services = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() as? [AnyObject] else {
            return []
        }
        var out: [(String, Double)] = []
        for service in services {
            let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?
                .takeRetainedValue() as? String ?? "unknown"
            guard let event = IOHIDServiceClientCopyEvent(service, kTemperatureEvent, 0, 0)?
                .takeRetainedValue() else { continue }
            let value = IOHIDEventGetFloatValue(event, kTemperatureField)
            if value > 0, value < 150 { out.append((name, value)) }
        }
        return out
    }

    private static let kTemperatureEvent: Int64 = 15
    private static let kTemperatureField: Int32 = 15 << 16
}

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: AnyObject, _ matching: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: AnyObject, _ key: CFString) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int64, _ a: Int32, _ b: Int64) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: AnyObject, _ field: Int32) -> Double
