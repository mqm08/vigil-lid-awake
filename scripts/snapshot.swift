// Renders PanelView to PNG (light + dark) for the README.
import AppKit
import SwiftUI

@main
struct Snapshot {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        if let icon = NSImage(contentsOfFile: "build/icon-1024.png") { app.applicationIconImage = icon }

        let store = Store()
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let root = PanelView()
                .environmentObject(store)
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: root)
            host.appearance = NSAppearance(named: appearance)
            host.frame = CGRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))

            let scale: CGFloat = 2
            let size = host.bounds.size
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = size
            host.cacheDisplay(in: host.bounds, to: rep)
            let url = URL(fileURLWithPath: "docs/panel-\(name).png")
            try! rep.representation(using: .png, properties: [:])!.write(to: url)
            print("wrote \(url.path)")
        }
    }
}
