// vigil-sensors — prints temperature readings as JSON for the root daemon.
//   vigil-sensors         {"chip":72.3,"battery":38.6,"ssd":55}
//   vigil-sensors --all   every sensor, for debugging
import Foundation

if CommandLine.arguments.contains("--all") {
    for (name, value) in Sensors.all().sorted(by: { $0.0 < $1.0 }) {
        print(String(format: "%-32@ %6.1f", name as NSString, value))
    }
} else {
    let data = try! JSONEncoder().encode(Sensors.read())
    print(String(data: data, encoding: .utf8)!)
}
