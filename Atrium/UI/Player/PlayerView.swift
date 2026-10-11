// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// The game edge to edge, with overlays in fixed zones so the middle of the
/// image is only covered by panels. See docs/DESIGN_SPEC.md, section I.
struct PlayerView: View {
    @Environment(EmulationSession.self) private var session
    @Environment(CoreManager.self) private var cores
    @Environment(\.modelContext) private var context
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @AppStorage(PrefKey.videoFilter) private var globalFilter = VideoFilter.sharp.rawValue
    @AppStorage(PrefKey.bezel) private var bezel: BezelStyle = .none
    @AppStorage(PrefKey.integerScaling) private var integerScaling = false
    /// Bumped when any preference changes: per-system filters and bezel
    /// images have no fixed key to observe.
    @State private var preferencesRevision = 0
    @AppStorage(PrefKey.showFPS) private var showFPS = false
    @AppStorage(PrefKey.settingsTab) private var settingsTab = SettingsTab.general
    @State private var menu = PanelPresence()
    @State private var shaderPanel = PanelPresence()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Created per game: SwiftUI reuses the player's views when the
            // window reopens, and a reused MTKView never resumes drawing.
            if session.phase == .running {
                GameMetalView(session: session, selection: shaderSelection, integerScaling: integerScaling, bezel: bezel,
                              bezelImage: bezelImage)
                    .ignoresSafeArea()
            }

            switch session.phase {
            case .idle, .running, .external:
                EmptyView()
            case .preparing(let message):
                PreparingView(title: session.gameTitle, message: message, progress: currentDownloadProgress)
            case .failed(let failure):
                FailureView(failure: failure, openSettings: { open(failure.settingsTab) }, close: closePlayer)
            }

            // Always in the tree: its fade-out is animated only that way.
            // Clicking next to the panel resumes.
            Rectangle()
                .fill(.black.opacity(reduceTransparency ? 0.7 : 0.5))
                .ignoresSafeArea()
                .onTapGesture { session.isMenuVisible = false }
                .opacity(menu.isVisible ? 1 : 0)
                .allowsHitTesting(menu.isVisible)
                .accessibilityHidden(true)
            if menu.isPresent {
                GeometryReader { geometry in
                    PauseMenuView(maxHeight: min(600, geometry.size.height - 80), close: closePlayer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.appFade(or: .opacity.combined(with: .scale(scale: 0.97)), reduceMotion: reduceMotion))
                .scaleEffect(menu.isClosing && !reduceMotion ? 0.97 : 1)
                .opacity(menu.isClosing ? 0 : 1)
                .allowsHitTesting(!menu.isClosing)
            }
        }
        .overlay(alignment: .topTrailing) {
            if shaderPanel.isPresent {
                ShaderPanel()
                    .padding(AppSpacing.l)
                    .transition(.appFade(or: .move(edge: .trailing).combined(with: .opacity), reduceMotion: reduceMotion))
                    .offset(x: shaderPanel.isClosing && !reduceMotion ? 40 : 0)
                    .opacity(shaderPanel.isClosing ? 0 : 1)
                    .allowsHitTesting(!shaderPanel.isClosing)
            }
        }
        .overlay(alignment: .top) {
            ToastStack(toasts: session.toasts)
                .padding(.top, AppSpacing.l)
        }
        .overlay(alignment: .topTrailing) {
            ModeIndicators(showsFPS: showFPS)
                .padding(AppSpacing.l)
                // Beside the shader panel, which takes the corner.
                .padding(.trailing, shaderPanel.isPresent ? 320 + AppSpacing.l : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            AchievementIndicators(indicators: session.achievementIndicators)
                .padding(AppSpacing.l)
        }
        .appAnimation(AppAnimation.standard, value: session.toasts)
        .appAnimation(AppAnimation.standard, value: session.isFastForwarding)
        .appAnimation(AppAnimation.standard, value: session.isRewinding)
        .appAnimation(AppAnimation.standard, value: session.isTyping)
        .appAnimation(AppAnimation.standard, value: session.achievementIndicators)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            preferencesRevision += 1
        }
        .navigationTitle(session.gameTitle)
        .toolbar(session.phase == .running && !session.isMenuVisible ? .hidden : .automatic, for: .windowToolbar)
        .onChange(of: session.isMenuVisible, initial: true) { _, visible in
            animate($menu, toVisible: visible) { session.isMenuVisible }
        }
        .onChange(of: session.isShaderPanelVisible) { _, visible in
            animate($shaderPanel, toVisible: visible) { session.isShaderPanelVisible }
        }
        .onDisappear {
            // A standalone emulator's game closed the player; it keeps running.
            guard session.standaloneName == nil else { return }
            Task { await session.stop(context: context) }
        }
        .onChange(of: session.standaloneName) { _, name in
            // Started while a game ran here: the new one has its own window.
            if name != nil { dismissWindow(id: WindowID.player) }
        }
        .onChange(of: session.coreTerminations) {
            // A core that shut itself down closes the player. Not tied to
            // phase == .idle: that also follows closing the window, and SwiftUI
            // delivers it when the window reopens, closing it right away.
            dismissWindow(id: WindowID.player)
        }
    }

    private var currentDownloadProgress: Double? {
        cores.downloads.values.first
    }

    /// The shader editor's draft while it previews on the game; else the
    /// game's own filter or preset, its system's, or the one for all systems.
    private var shaderSelection: ShaderSelection {
        if let draft = session.shader.editorPreset { return .preset(draft) }
        #if DEBUG
        // Development aid: ATRIUM_SHADER=<filter|preset:library/…|preset:user/…> replaces the choice.
        if let selection = DebugEnvironment.shader { return selection }
        #endif
        _ = (preferencesRevision, globalFilter)
        return ShaderSelection.current(for: session.systemID, gameID: session.runningGameID)
    }

    /// The system's bezel image, when the user chose one.
    private var bezelImage: URL? {
        _ = preferencesRevision
        return session.systemID.flatMap { BezelImages.image(for: $0) }
    }

    /// Fades a panel in, or out and then removes it, unless `isWanted`
    /// reports it was reopened while it faded.
    private func animate(_ presence: Binding<PanelPresence>, toVisible visible: Bool, isWanted: @escaping () -> Bool) {
        if visible {
            withAppAnimation(AppAnimation.panel, reduceMotion: reduceMotion) { presence.wrappedValue.show() }
        } else if presence.wrappedValue.isPresent {
            withAppAnimation(AppAnimation.panel, reduceMotion: reduceMotion) {
                presence.wrappedValue.beginClosing()
            } completion: {
                guard !isWanted() else { return }
                presence.wrappedValue.remove()
            }
        }
    }

    private func closePlayer() {
        dismissWindow(id: WindowID.player)
    }

    private func open(_ tab: SettingsTab?) {
        if let tab { settingsTab = tab }
        openSettings()
    }
}

/// A panel the player shows and hides by hand. It fades in with its
/// insertion transition; a removal transition is never animated here, so
/// closing fades it out and removes its views afterwards.
private struct PanelPresence {
    /// The panel is in the view tree.
    private(set) var isPresent = false
    /// The panel is fading out.
    private(set) var isClosing = false

    var isVisible: Bool { isPresent && !isClosing }

    mutating func show() {
        isPresent = true
        isClosing = false
    }

    mutating func beginClosing() {
        isClosing = true
    }

    mutating func remove() {
        isPresent = false
        isClosing = false
    }
}

/// Indicators that stay while their mode is on.
private struct ModeIndicators: View {
    @Environment(EmulationSession.self) private var session
    let showsFPS: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if showsFPS, session.phase == .running {
                HUDCapsule {
                    Text("\(session.measuredFPS, format: .number.precision(.fractionLength(1))) fps")
                        .font(.caption.monospacedDigit())
                }
            }
            if session.isFastForwarding {
                HUDCapsule { Label("Fast Forward", systemImage: "forward.fill") }
                    .transition(.opacity)
            }
            if session.isRewinding {
                HUDCapsule { Label("Rewind", systemImage: "backward.fill") }
                    .transition(.opacity)
            }
            if session.isTyping {
                HUDCapsule { Label("Typing", systemImage: "keyboard") }
                    .transition(.opacity)
            }
            if session.isHardcore {
                HUDCapsule { Label("Hardcore", systemImage: "trophy.fill") }
                    .transition(.opacity)
            }
        }
    }
}

private struct PreparingView: View {
    let title: String
    let message: String
    let progress: Double?

    /// Quick starts finish before the panel appears, so they show no flash.
    @State private var isShown = false

    var body: some View {
        PlayerPanel {
            VStack(spacing: AppSpacing.m) {
                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                } else {
                    ProgressView()
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: 300 - 2 * AppSpacing.xl)
        }
        .opacity(isShown ? 1 : 0)
        .appAnimation(AppAnimation.standard, value: isShown)
        .accessibilityElement(children: .combine)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isShown = true
        }
    }
}

private struct FailureView: View {
    let failure: EmulationSession.Failure
    let openSettings: () -> Void
    let close: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        PlayerPanel(padding: 28) {
            VStack(spacing: AppSpacing.l) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(spacing: AppSpacing.s) {
                    Text("The game couldn't be started")
                        .font(.title3.weight(.semibold))
                    Text(failure.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                HStack {
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.glass)
                    Button("Close", action: close)
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .frame(maxWidth: 420 - 2 * 28)
        }
        // Focused so Esc reaches it: Esc closes, like the Close button.
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onExitCommand(perform: close)
        .onAppear { isFocused = true }
    }
}

/// Short messages about what just happened, newest last.
struct ToastStack: View {
    let toasts: [EmulationSession.Toast]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(toasts) { toast in
                HUDCapsule {
                    Label {
                        if let detail = toast.detail {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(toast.text)
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(toast.text)
                        }
                    } icon: {
                        if let imageURL = toast.imageURL {
                            RemoteBadge(url: imageURL, size: 32)
                        } else if let symbol = symbol(for: toast.kind) {
                            Image(systemName: symbol)
                                .foregroundStyle(toast.kind == .warning ? AnyShapeStyle(.orange)
                                                 : toast.kind == .achievement ? AnyShapeStyle(.yellow) : AnyShapeStyle(.primary))
                        }
                    }
                    .labelStyle(ToastLabelStyle())
                }
                .transition(.appFade(or: .move(edge: .top).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
    }

    private func symbol(for kind: EmulationSession.Toast.Kind) -> String? {
        switch kind {
        case .info: nil
        case .saved: "square.and.arrow.down"
        case .loaded: "square.and.arrow.up"
        case .warning: "exclamationmark.triangle.fill"
        case .screenshot: "camera.fill"
        case .achievement: "trophy.fill"
        }
    }
}

/// Running challenges, achievement progress and leaderboard values, in the
/// bottom corner where they cover the least of the game.
private struct AchievementIndicators: View {
    let indicators: [EmulationSession.AchievementIndicator]

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            ForEach(indicators) { indicator in
                HUDCapsule {
                    HStack(spacing: 6) {
                        if let url = indicator.imageURL {
                            RemoteBadge(url: url, size: 22)
                        } else if indicator.kind == .tracker {
                            Image(systemName: "stopwatch")
                        }
                        if let value = indicator.value {
                            Text(value)
                                .monospacedDigit()
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A RetroAchievements badge, loaded from the web.
struct RemoteBadge: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().interpolation(.medium)
        } placeholder: {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size / 6))
        .accessibilityHidden(true)
    }
}

/// Icon and title like `.titleAndIcon`, without the gap an empty icon leaves.
private struct ToastLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}
