// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(PrefKey.accentColor) private var accent = AccentChoice.automatic
    @AppStorage(PrefKey.customAccentColor) private var customAccent = AccentChoice.defaultCustomColor

    var body: some View {
        Form {
            Section {
                LabeledContent("Accent Color") {
                    HStack(spacing: AppSpacing.s) {
                        ForEach(AccentChoice.allCases.filter { $0 != .custom }) { choice in
                            AccentSwatch(choice: choice, isSelected: accent == choice) { accent = choice }
                        }
                    }
                }
                ColorPicker(selection: Binding(
                    get: { Color(hex: UInt32(truncatingIfNeeded: customAccent)) },
                    set: { color in
                        customAccent = color.hexValue
                        accent = .custom
                    }), supportsOpacity: false) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Custom Color")
                        if accent == .custom {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityLabel(Text("Selected"))
                        }
                    }
                }
            } header: {
                Text("Color")
            } footer: {
                Text("Selections, buttons, switches and favorites use the accent color. Automatic follows the accent color in System Settings and uses blue when it is set to Multicolor. The selection in the sidebar and in lists takes the closest system accent color the next time Atrium opens.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
    }
}

/// A round colour button, like the accent colours in System Settings.
private struct AccentSwatch: View {
    let choice: AccentChoice
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private static let size: CGFloat = 18

    var body: some View {
        Button(action: select) {
            fill
                .frame(width: Self.size, height: Self.size)
                .overlay { Circle().strokeBorder(.primary.opacity(contrast == .increased ? 0.4 : 0.15), lineWidth: 0.5) }
                .padding(AppMetrics.selectionRingGap)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(.primary.opacity(0.55), lineWidth: 2)
                    }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(choice.title)
        .accessibilityLabel(Text(verbatim: choice.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var fill: some View {
        if choice == .automatic {
            // The multicolour wheel System Settings shows.
            Circle().fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        } else if let color = choice.color(custom: AccentChoice.defaultCustomColor) {
            Circle().fill(color)
        }
    }
}
