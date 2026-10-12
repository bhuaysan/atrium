// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

extension AccentChoice {
    /// Whether AppKit runs with Atrium's own system accent since launch
    /// (`Preferences.applySystemAccent()`).
    static var systemAccentIsOverridden = false

    /// The colour this choice tints the app with; nil leaves the accent to the system.
    func color(custom: Int) -> Color? {
        switch self {
        case .automatic:
            // AppKit keeps the accent this launch started with.
            Self.systemAccentIsOverridden
                ? Preferences.globalSystemAccent.map(Self.systemColor) ?? Color("AccentColor")
                : nil
        case .blue: Color("AccentColor")
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .graphite: .gray
        case .coral: Color(light: 0xFA5A65, dark: 0xFF6F78)
        case .custom: Color(hex: UInt32(truncatingIfNeeded: custom))
        }
    }

    /// A macOS accent colour as `AppleAccentColor` stores it.
    private static func systemColor(_ accent: Int) -> Color {
        switch accent {
        case 0: .red
        case 1: .orange
        case 2: .yellow
        case 3: .green
        case 5: .purple
        case 6: .pink
        case -1: .gray
        default: .blue
        }
    }
}

extension Color {
    /// A colour with its own Dark Mode variant.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(Color(hex: hex))
        })
    }

    /// The colour as 0xRRGGBB in sRGB, for storing a picked colour.
    var hexValue: Int {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return AccentChoice.defaultCustomColor }
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return channel(rgb.redComponent) << 16 | channel(rgb.greenComponent) << 8 | channel(rgb.blueComponent)
    }
}

extension View {
    /// Tints a window with the accent picked in Settings › Appearance. Every
    /// scene's root view applies it; drawings use `.tint`, not `Color.accentColor`,
    /// which ignores the choice.
    func appAccent() -> some View {
        modifier(AppAccentModifier())
    }
}

private struct AppAccentModifier: ViewModifier {
    @AppStorage(PrefKey.accentColor) private var choice = AccentChoice.automatic
    @AppStorage(PrefKey.customAccentColor) private var custom = AccentChoice.defaultCustomColor

    func body(content: Content) -> some View {
        let color = choice.color(custom: custom)
        content
            .tint(color)
            .environment(\.pickedAccent, color)
    }
}

extension EnvironmentValues {
    /// The accent picked in Settings › Appearance, for code that needs a
    /// `Color` rather than the `.tint` shape style; nil when it is the system's.
    @Entry var pickedAccent: Color?
}
