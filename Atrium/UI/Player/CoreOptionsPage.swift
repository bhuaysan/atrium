// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The pause menu's Core Options page: the running core's options, filterable.
struct CoreOptionsPage: View {
    @Environment(EmulationSession.self) private var session
    @State private var values: [String: String] = [:]
    @State private var filter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilterField(text: $filter)
                .padding(.bottom, AppSpacing.s)
            Toggle("Only for This Game", isOn: Binding(
                get: { session.usesGameCoreOptions },
                set: { enabled in
                    session.setUsesGameCoreOptions(enabled)
                    values = [:]
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Changes apply to this game only. Off: they apply to every game of this core.")
            .padding(.bottom, session.renderer == nil ? AppSpacing.m : AppSpacing.xs)
            if session.renderer != nil {
                // Cores with a Vulkan renderer: how the game renders, and where to change it.
                Text("Renders with \(StateRenderer(session.graphicsAPI).displayName). Choose the graphics API in Settings → Cores; it applies when the game starts again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, AppSpacing.m)
            }
            FittingScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(options, id: \.key) { option in
                        optionRow(option)
                        PanelDivider()
                    }
                    if options.isEmpty {
                        Text(filter.isEmpty ? "This core has no options." : "No options match “\(filter)”.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Text("Some options apply after a reset.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: AppSpacing.m)
                Button("Reset Game") { session.reset() }
                Button("Restore Defaults") {
                    session.resetCoreOptions()
                    values = [:]
                }
            }
            .buttonStyle(.borderless)
            .padding(.top, AppSpacing.m)
        }
    }

    private func optionRow(_ option: CoreOption) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(option.title)
                    .font(.body)
                if let info = option.info {
                    Text(info)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(info)
                }
            }
            Spacer(minLength: AppSpacing.m)
            Picker(option.title, selection: binding(for: option)) {
                ForEach(Array(zip(option.values, option.labels)), id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: 200, alignment: .trailing)
        }
    }

    private var options: [CoreOption] {
        let all = session.core?.options ?? []
        guard !filter.isEmpty else { return all }
        return all.filter { $0.title.localizedStandardContains(filter) || $0.key.localizedStandardContains(filter) }
    }

    private func binding(for option: CoreOption) -> Binding<String> {
        Binding(
            get: { values[option.key] ?? session.core?.value(forOption: option.key) ?? option.defaultValue },
            set: { value in
                values[option.key] = value
                session.setCoreOption(value, for: option.key)
            }
        )
    }
}
