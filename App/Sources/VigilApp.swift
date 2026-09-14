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
        Image(nsImage: active ? MenuBarGlyph.on : MenuBarGlyph.off)
            .accessibilityLabel(active ? "守夜中" : "守夜已关闭")
    }
}
