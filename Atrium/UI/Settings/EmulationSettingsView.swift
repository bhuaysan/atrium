// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore
import SwiftUI
import UniformTypeIdentifiers

struct EmulationSettingsView: View {
    @Environment(EmulationSession.self) private var session
    @AppStorage(PrefKey.videoFilter) private var filter: ShaderSelection = .builtin(.sharp)
    @AppStorage(PrefKey.integerScaling) private var integerScaling = false
    @AppStorage(PrefKey.showFPS) private var showFPS = false
    @AppStorage(PrefKey.volume) private var volume = 1.0
    @AppStorage(PrefKey.pauseInBackground) private var pauseInBackground = true
    @AppStorage(PrefKey.autosaveOnQuit) private var autosaveOnQuit = true
    @AppStorage(PrefKey.periodicAutosave) private var periodicAutosave = false
    @AppStorage(PrefKey.resumeAutomatically) private var resumeAutomatically = true
    @AppStorage(PrefKey.bezel) private var bezel: BezelStyle = .none
    @AppStorage(PrefKey.fastForwardSpeed) private var fastForwardSpeed = 4.0
    @AppStorage(PrefKey.rewindEnabled) private var rewindEnabled = false
    @AppStorage(PrefKey.rewindBufferSize) private var rewindBufferSize = 256
    @AppStorage(PrefKey.runAheadFrames) private var runAheadFrames = 0
    @State private var coreChoices: [String: String] = [:]

    var body: some View {
        Form {
            Section {
                ShaderPicker(title: "Filter", selection: Binding(get: { filter }, set: { if let choice = $0 { filter = choice } }))
                Picker("Around the Picture", selection: $bezel) {
                    ForEach(BezelStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle(isOn: $integerScaling) {
                    Text("Integer Scaling")
                    Text("Scales the picture by whole multiples only, so every pixel has the same size. Leaves a border around the picture.")
                }
                Toggle(isOn: $showFPS) {
                    Text("Show Frame Rate")
                    Text("Shows frames per second in the corner of the player.")
                }
            } header: {
                Text("Video")
            } footer: {
                Text("CRT and Handheld LCD show their lines and pixel grid once the window is large enough. Ambient Light fills the space around the picture with its colours.")
                    .settingsFootnote()
            }
            SystemVideoSection()
            ShaderSettingsSection()
            Section {
                Picker("Fast Forward Speed", selection: $fastForwardSpeed) {
                    ForEach([2.0, 3.0, 4.0, 6.0, 8.0], id: \.self) { speed in
                        Text("\(Int(speed))×").tag(speed)
                    }
                    Divider()
                    Text("As Fast as Possible").tag(0.0)
                }
                Toggle(isOn: $rewindEnabled) {
                    Text("Rewind")
                    Text("Hold the Rewind key to run the game backwards. Records the game while you play, which takes memory and some processing power.")
                }
                if rewindEnabled {
                    Picker("Memory for Rewinding", selection: $rewindBufferSize) {
                        ForEach([128, 256, 512, 1024], id: \.self) { size in
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size) << 20, countStyle: .memory)).tag(size)
                        }
                    }
                }
                Picker(selection: $runAheadFrames) {
                    Text("Off").tag(0)
                    Text("1 Frame").tag(1)
                    Text("2 Frames").tag(2)
                    Text("3 Frames").tag(3)
                } label: {
                    Text("Run-Ahead")
                    Text("Hides the input lag games have built in: the game runs a few frames ahead, so a press shows up sooner. Too many frames make the picture jump. Needs a core that saves states; costs processing power.")
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("Rewind and run-ahead don't work with every core. In RetroAchievements hardcore mode rewind is off.")
                    .settingsFootnote()
            }
            .onChange(of: fastForwardSpeed) { session.reloadPlaybackSettings() }
            .onChange(of: rewindEnabled) { session.reloadPlaybackSettings() }
            .onChange(of: rewindBufferSize) { session.reloadPlaybackSettings() }
            .onChange(of: runAheadFrames) { session.reloadPlaybackSettings() }
            Section("Audio") {
                Slider(value: $volume, in: 0...1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                .onChange(of: volume) { _, value in session.setVolume(value) }
            }
            Section("Behavior") {
                Toggle(isOn: $pauseInBackground) {
                    Text("Pause in Background")
                    Text("Pauses the game while another app is active.")
                }
            }
            Section {
                Toggle(isOn: $autosaveOnQuit) {
                    Text("Save When Quitting a Game")
                    Text("Keeps where you are in an automatic save state, apart from your slots.")
                }
                Toggle(isOn: $periodicAutosave) {
                    Text("Also Save Every 5 Minutes")
                    Text("Protects your progress if the game or the Mac stops unexpectedly.")
                }
                .disabled(!autosaveOnQuit)
                Toggle(isOn: $resumeAutomatically) {
                    Text("Resume Where You Left Off")
                    Text("Play continues from the automatic state. Start from Beginning is in the game's menu.")
                }
            } header: {
                Text("Resume")
            } footer: {
                Text("Some cores can't save states; their games always start from the beginning. Battery saves are kept either way.")
                    .settingsFootnote()
            }
            Section {
                ForEach(SystemCatalog.all.filter { $0.cores.count > 1 }) { system in
                    Picker(system.name, selection: Binding(
                        get: { coreChoices[system.id] ?? Preferences.coreChoice(for: system.id) ?? system.defaultCore.id },
                        set: { coreChoices[system.id] = $0; Preferences.setCoreChoice($0, for: system.id) }
                    )) {
                        ForEach(system.cores) { core in
                            Group {
                                if core.id == system.defaultCore.id {
                                    Text("\(core.name) (Recommended)")
                                } else {
                                    Text(core.name)
                                }
                            }
                            .tag(core.id)
                        }
                    }
                }
            } header: {
                Text("Default Cores")
            } footer: {
                Text("Individual games can override the core in their info panel.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
    }
}

/// A filter and a bezel image for one system.
private struct SystemVideoSection: View {
    @State private var systemID = SystemCatalog.all[0].id
    @AppStorage(PrefKey.videoFilter) private var globalFilter: ShaderSelection = .builtin(.sharp)
    @State private var filter: ShaderSelection?
    @State private var bezelImage: URL?
    @State private var isChoosingImage = false
    @State private var failure: String?

    var body: some View {
        Section {
            Picker("System", selection: $systemID) {
                ForEach(SystemCatalog.all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { system in
                    Text(system.name).tag(system.id)
                }
            }
            // A closure, not `set: setFilter`: the method reference crashes the Swift 6.2 compiler (Xcode 26).
            ShaderPicker(title: "Filter", selection: Binding(get: { filter }, set: { setFilter($0) }),
                         inheritTitle: String(localized: "Same as All Systems (\(globalFilter.title))"))
            LabeledContent("Bezel Image") {
                HStack(spacing: AppSpacing.s) {
                    if let bezelImage {
                        Text(bezelImage.lastPathComponent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Remove") { removeImage() }
                    }
                    Button(bezelImage == nil ? "Choose…" : "Change…") { isChoosingImage = true }
                }
            }
            if let failure {
                StatusLabel("The image couldn't be used", kind: .error, detail: failure)
            }
        } header: {
            Text("Per System")
        } footer: {
            Text("A bezel image is drawn over the game, so it needs a transparent window for the picture. Images for 16:9 screens with the picture in the middle fit best.")
                .settingsFootnote()
        }
        .onChange(of: systemID, initial: true) { load() }
        .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.png]) { result in
            if case .success(let url) = result { setImage(url) }
        }
    }

    private func load() {
        filter = UserDefaults.standard.string(forKey: PrefKey.systemVideoFilter(systemID)).flatMap(ShaderSelection.init(rawValue:))
        bezelImage = BezelImages.image(for: systemID)
        failure = nil
    }

    private func setFilter(_ value: ShaderSelection?) {
        filter = value
        UserDefaults.standard.set(value?.rawValue, forKey: PrefKey.systemVideoFilter(systemID))
    }

    private func setImage(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            try BezelImages.setImage(url, for: systemID)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
        bezelImage = BezelImages.image(for: systemID)
        Self.notifyPlayer()
    }

    private func removeImage() {
        try? BezelImages.removeImage(for: systemID)
        bezelImage = nil
        Self.notifyPlayer()
    }

    /// The player redraws with the new image (it watches preference changes).
    private static func notifyPlayer() {
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
    }
}
