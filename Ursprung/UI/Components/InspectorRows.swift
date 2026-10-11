// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A titled group of inspector rows, separated from the next by space only.
struct InfoSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                content
            }
        }
    }
}

/// A setting or extra as symbol and value, with an optional quiet note after
/// it; the title is the symbol's tooltip.
struct SymbolRow<Value: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    var note: LocalizedStringKey?
    @ViewBuilder let value: Value

    init(_ title: LocalizedStringKey, symbol: String, note: LocalizedStringKey? = nil, @ViewBuilder value: () -> Value) {
        self.title = title
        self.symbol = symbol
        self.note = note
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .help(Text(title))
                .accessibilityHidden(true)
            value
            if let note {
                Text(note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A menu picker drawn as its value and a small arrow, so it reads as part
/// of a line of text rather than as a form field.
struct InlineMenu: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .labelsHidden()
            .fixedSize()
            // The borderless pop-up insets its title; this lines it up with
            // plain text in the rows above and below.
            .padding(.leading, -3)
    }
}
