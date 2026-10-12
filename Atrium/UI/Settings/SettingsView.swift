// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore
import SwiftUI

/// The Settings tabs. The selected one is stored, so other windows can open a specific tab.
enum SettingsTab: String {
    case general, appearance, metadata, emulation, controls, achievements, cores, bios
}

struct SettingsView: View {
    @AppStorage(PrefKey.settingsTab) private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: .general) { GeneralSettingsView() }
            Tab("Appearance", systemImage: "paintpalette", value: .appearance) { AppearanceSettingsView() }
            Tab("Metadata", systemImage: "text.below.photo", value: .metadata) { MetadataSettingsView() }
            Tab("Emulation", systemImage: "display", value: .emulation) { EmulationSettingsView() }
            Tab("Controls", systemImage: "gamecontroller", value: .controls) { ControlsSettingsView() }
            Tab("Achievements", systemImage: "trophy", value: .achievements) { AchievementsSettingsView() }
            Tab("Cores", systemImage: "cpu", value: .cores) { CoresSettingsView() }
            Tab("BIOS", systemImage: "memorychip", value: .bios) { BIOSSettingsView() }
        }
        .scenePadding()
        .background { VerticallyResizableWindow() }
    }
}

/// The Settings scene's window is not resizable, and SwiftUI clears the flag
/// again after opening it. Long tabs like Controls and BIOS need more height,
/// so the window keeps a resize handle; the width stays fixed by the content.
private struct VerticallyResizableWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizingView { ResizingView() }
    func updateNSView(_ view: ResizingView, context: Context) {}

    final class ResizingView: NSView {
        private var observation: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observation = nil
            guard let window else { return }
            window.styleMask.insert(.resizable)
            observation = window.observe(\.styleMask) { window, _ in
                MainActor.assumeIsolated {
                    if !window.styleMask.contains(.resizable) { window.styleMask.insert(.resizable) }
                }
            }
        }
    }
}
