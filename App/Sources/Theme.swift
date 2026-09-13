import SwiftUI

enum Theme {
    /// Warm amber — the "someone is keeping watch" light.
    static let ember = Color(red: 1.00, green: 0.66, blue: 0.24)
    static let emberDeep = Color(red: 0.96, green: 0.45, blue: 0.16)
    /// Night blue from the app icon.
    static let night = Color(red: 0.16, green: 0.18, blue: 0.42)
    static let nightDeep = Color(red: 0.05, green: 0.06, blue: 0.16)

    static let radius: CGFloat = 14
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// A tinted rounded-square SF Symbol, like System Settings rows.
struct SymbolBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}
