import SwiftUI

@main
struct VigilApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(store)
        } label: {
            MenuBarIcon(active: {
                if case .active = store.status { return true }
                return false
            }())
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIcon: View {
    let active: Bool

    var body: some View {
        Image(nsImage: active ? Self.onImage : Self.offImage)
            .accessibilityLabel(active ? "守夜中" : "守夜已关闭")
    }

    /// Amber, non-template: the only coloured icon in the menu bar, so it reads at a glance.
    private static let onImage: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [
                NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1)
            ]))
        let image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        image.isTemplate = false
        return image
    }()

    /// Monochrome template, matches the rest of the menu bar.
    private static let offImage: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }()
}
