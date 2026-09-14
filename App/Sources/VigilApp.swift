import SwiftUI

@main
struct VigilApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(store)
        } label: {
            MenuBarIcon(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar glyph.
///
/// `MenuBarExtra`'s label is notoriously unreliable about re-rendering on
/// observed-object changes: a plain `Bool` parameter freezes at Scene-build
/// time, and even `@EnvironmentObject` didn't redraw it in testing. So this
/// keeps its own `@State` mirror of the flag and repaints on a timer, which
/// does not depend on SwiftUI noticing the change for us.
struct MenuBarIcon: View {
    @ObservedObject var store: Store
    @State private var active = false

    private let heartbeat = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isActive: Bool {
        if case .active = store.status { return true }
        return false
    }

    var body: some View {
        Image(nsImage: active ? MenuBarGlyph.on : MenuBarGlyph.off)
            .renderingMode(.original)
            .accessibilityLabel(active ? "守夜中" : "守夜已关闭")
            .onReceive(heartbeat) { _ in
                let now = isActive
                if now != active { active = now }
            }
            .onAppear { active = isActive }
    }
}
