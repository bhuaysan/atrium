// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// UserDefaults keys. Views bind with `@AppStorage(PrefKey.…)`, services read
/// through `Preferences`.
public nonisolated enum PrefKey {
    public static let libraryFolders = "libraryFolders"
    public static let scraperLanguage = "scraperLanguage"
    public static let scraperRegion = "scraperRegion"
    public static let scraperUsername = "scraperUsername"
    public static let autoScrape = "autoScrape"
    public static let videoFilter = "videoFilter"
    public static let integerScaling = "integerScaling"
    public static let volume = "volume"
    public static let pauseInBackground = "pauseInBackground"
    public static let showFPS = "showFPS"
    public static let gridSize = "gridSize"
    public static let keyboardMapping = "keyboardMapping"
    public static let librarySort = "librarySort"
    public static let settingsTab = "settingsTab"
    public static let autosaveOnQuit = "autosaveOnQuit"
    public static let periodicAutosave = "periodicAutosave"
    public static let resumeAutomatically = "resumeAutomatically"
    public static let controllerMapping = "controllerMapping"
    public static let turboButtons = "turboButtons"
    public static let hotkeys = "hotkeys"
    public static let portAssignments = "portAssignments"
    public static let stickDeadZone = "stickDeadZone"
    public static let collections = "collections"
    public static let libraryViewMode = "libraryViewMode"
    public static let groupsVariants = "groupsVariants"
    public static let preferredRegions = "preferredRegions"
    public static let fastForwardSpeed = "fastForwardSpeed"
    public static let rewindEnabled = "rewindEnabled"
    public static let rewindBufferSize = "rewindBufferSize"
    public static let runAheadFrames = "runAheadFrames"
    public static let turboRate = "turboRate"
    public static let rumble = "rumble"
    public static let bezel = "bezel"
    public static let achievementsEnabled = "achievementsEnabled"
    public static let achievementsUsername = "achievementsUsername"
    public static let achievementsHardcore = "achievementsHardcore"
    public static let achievementsShowsProgress = "achievementsShowsProgress"
    /// Standalone emulators (PlayStation 2) open their game window in full screen.
    public static let standaloneFullscreen = "standaloneFullscreen"
    /// Favourite RetroArch presets, as `ShaderSelection` raw values.
    public static let shaderFavorites = "shaderFavorites"
    /// Path of the folder structure Atrium created (`FolderStructure`).
    public static let folderStructure = "folderStructure"
    /// Systems whose folder the structure has had, so a folder the user
    /// deleted is not created again; only new systems get one.
    public static let folderStructureSystems = "folderStructureSystems"
    /// Whether the first launch has offered the folder structure.
    public static let folderStructureOffered = "folderStructureOffered"
    /// `AccentChoice` raw value, picked in Settings › Appearance.
    public static let accentColor = "accentColor"
    /// The user's own accent as 0xRRGGBB, used by `AccentChoice.custom`.
    public static let customAccentColor = "customAccentColor"
    public static func systemVideoFilter(_ systemID: String) -> String { "videoFilter.\(systemID)" }
    /// A game's own filter or preset; wins over its system's.
    public static func gameVideoFilter(_ gameID: UUID) -> String { "\(gameVideoFilterPrefix)\(gameID.uuidString)" }
    public static let gameVideoFilterPrefix = "videoFilter.game."
    public static func inputProfile(_ systemID: String) -> String { "inputProfile.\(systemID)" }
    public static func coreChoice(_ systemID: String) -> String { "coreChoice.\(systemID)" }
    public static func coreOptions(_ coreID: String) -> String { "coreOptions.\(coreID)" }
    public static func rendererChoice(_ coreID: String) -> String { "rendererChoice.\(coreID)" }
    public static func hidGamepadMapping(_ deviceKey: String) -> String { "hidGamepadMapping.\(deviceKey)" }
}

/// Display filter applied when scaling the emulator image.
/// The graphics API the user picked for a core in Settings › Cores.
public nonisolated enum RendererChoice: String, CaseIterable, Identifiable, Sendable {
    /// What the catalog recommends for the core.
    case automatic
    case vulkan
    case opengl

    public var id: String { rawValue }
}

public nonisolated enum VideoFilter: String, CaseIterable, Identifiable, Sendable {
    case sharp, nearest, smooth, scanlines, crt, crtCurved, lcd

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sharp: String(localized: "Sharp", bundle: .module)
        case .nearest: String(localized: "Pixel Perfect", bundle: .module)
        case .smooth: String(localized: "Smooth", bundle: .module)
        case .scanlines: String(localized: "Scanlines", bundle: .module)
        case .crt: String(localized: "CRT", bundle: .module)
        case .crtCurved: String(localized: "CRT, Curved", bundle: .module)
        case .lcd: String(localized: "Handheld LCD", bundle: .module)
        }
    }

    /// Index of the filter in the presentation shader.
    public var shaderIndex: UInt32 {
        switch self {
        case .sharp: 0
        case .nearest: 1
        case .smooth: 2
        case .scanlines: 3
        case .crt: 4
        case .crtCurved: 5
        case .lcd: 6
        }
    }
}

/// The app's accent colour, picked in Settings › Appearance.
public nonisolated enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    /// The accent colour from System Settings, or Atrium blue when that is Multicolour.
    case automatic
    case blue, purple, pink, red, orange, yellow, green, graphite, coral
    /// `PrefKey.customAccentColor`.
    case custom

    /// Atrium blue in Light Mode, the custom colour's starting value.
    public static let defaultCustomColor = 0x1F6BF5

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: String(localized: "Automatic", bundle: .module)
        case .blue: String(localized: "Blue", bundle: .module)
        case .purple: String(localized: "Purple", bundle: .module)
        case .pink: String(localized: "Pink", bundle: .module)
        case .red: String(localized: "Red", bundle: .module)
        case .orange: String(localized: "Orange", bundle: .module)
        case .yellow: String(localized: "Yellow", bundle: .module)
        case .green: String(localized: "Green", bundle: .module)
        case .graphite: String(localized: "Graphite", bundle: .module)
        case .coral: String(localized: "Coral", bundle: .module)
        case .custom: String(localized: "Custom", bundle: .module)
        }
    }

    /// The closest macOS accent colour, as System Settings stores it in
    /// `AppleAccentColor` (-1 graphite, 0 red … 6 pink); nil for automatic.
    public func systemAccent(custom: Int) -> Int? {
        switch self {
        case .automatic: nil
        case .graphite: -1
        case .red: 0
        case .orange: 1
        case .yellow: 2
        case .green: 3
        case .blue: 4
        case .purple: 5
        case .pink: 6
        case .coral: 0
        case .custom: Self.closestSystemAccent(to: custom)
        }
    }

    public static func closestSystemAccent(to hex: Int) -> Int {
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let high = max(r, g, b), low = min(r, g, b)
        guard high > 0, (high - low) / high >= 0.2 else { return -1 }
        var hue = switch high {
        case r: (g - b) / (high - low)
        case g: 2 + (b - r) / (high - low)
        default: 4 + (r - g) / (high - low)
        }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        let hues: [(accent: Int, hue: Double)] = [(0, 0), (1, 30), (2, 55), (3, 125), (4, 215), (5, 285), (6, 330), (0, 360)]
        return hues.min { abs($0.hue - hue) < abs($1.hue - hue) }!.accent
    }
}

/// What fills the space around the game picture.
public nonisolated enum BezelStyle: String, CaseIterable, Identifiable, Sendable {
    /// Black.
    case none
    /// A blurred, dimmed copy of the picture, as if it lit the room.
    case ambient

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: String(localized: "None", bundle: .module)
        case .ambient: String(localized: "Ambient Light", bundle: .module)
        }
    }
}

public nonisolated enum Preferences {
    private static var defaults: UserDefaults { .standard }

    public static func registerDefaults() {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let region: String = switch Locale.current.region?.identifier {
        case "US", "CA": "us"
        case "JP": "jp"
        default: "eu"
        }
        defaults.register(defaults: [
            PrefKey.scraperLanguage: ["de", "fr", "es", "it", "pt"].contains(languageCode) ? languageCode : "en",
            PrefKey.scraperRegion: region,
            PrefKey.autoScrape: true,
            PrefKey.videoFilter: VideoFilter.sharp.rawValue,
            PrefKey.integerScaling: false,
            PrefKey.volume: 1.0,
            PrefKey.pauseInBackground: true,
            PrefKey.showFPS: false,
            PrefKey.gridSize: 180.0,
            PrefKey.autosaveOnQuit: true,
            PrefKey.periodicAutosave: false,
            PrefKey.resumeAutomatically: true,
            PrefKey.stickDeadZone: 0.15,
            PrefKey.groupsVariants: true,
            PrefKey.fastForwardSpeed: 4.0,
            PrefKey.rewindEnabled: false,
            PrefKey.rewindBufferSize: 256,
            PrefKey.runAheadFrames: 0,
            PrefKey.turboRate: 3,
            PrefKey.rumble: true,
            PrefKey.bezel: BezelStyle.none.rawValue,
            PrefKey.achievementsEnabled: false,
            PrefKey.achievementsHardcore: false,
            PrefKey.achievementsShowsProgress: true,
            PrefKey.standaloneFullscreen: true,
            PrefKey.accentColor: AccentChoice.automatic.rawValue,
            PrefKey.customAccentColor: AccentChoice.defaultCustomColor,
        ])
    }

    /// AppKit draws the focused sidebar selection, table selection and focus
    /// rings in the system accent and ignores SwiftUI's `tint`. Atrium's own
    /// `AppleAccentColor` wins over the global one, so it gets them close to
    /// the picked accent. AppKit reads it at launch only. Atrium blue on a
    /// Multicolor system needs no override: that is the asset catalog's accent.
    /// Returns whether it overrides the system accent.
    public static func applySystemAccent() -> Bool {
        let choice = defaults.string(forKey: PrefKey.accentColor).flatMap(AccentChoice.init) ?? .automatic
        let systemIsMulticolor = defaults.persistentDomain(forName: UserDefaults.globalDomain)?[appleAccentColor] == nil
        if let accent = choice.systemAccent(custom: defaults.integer(forKey: PrefKey.customAccentColor)),
           !(choice == .blue && systemIsMulticolor) {
            defaults.set(accent, forKey: appleAccentColor)
            return true
        }
        defaults.removeObject(forKey: appleAccentColor)
        return false
    }

    private static let appleAccentColor = "AppleAccentColor"

    /// The accent picked in System Settings (`AppleAccentColor`); nil for Multicolor.
    public static var globalSystemAccent: Int? {
        defaults.persistentDomain(forName: UserDefaults.globalDomain)?[appleAccentColor] as? Int
    }

    public static var libraryFolders: [URL] {
        get { (defaults.stringArray(forKey: PrefKey.libraryFolders) ?? []).map { URL(filePath: $0, directoryHint: .isDirectory) } }
        set { defaults.set(newValue.map { $0.path(percentEncoded: false) }, forKey: PrefKey.libraryFolders) }
    }

    public static var folderStructure: URL? {
        get { defaults.string(forKey: PrefKey.folderStructure).map { URL(filePath: $0, directoryHint: .isDirectory) } }
        set { defaults.set(newValue?.path(percentEncoded: false), forKey: PrefKey.folderStructure) }
    }

    public static var folderStructureSystems: Set<String> {
        get { Set(defaults.stringArray(forKey: PrefKey.folderStructureSystems) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: PrefKey.folderStructureSystems) }
    }

    public static var folderStructureOffered: Bool {
        get { defaults.bool(forKey: PrefKey.folderStructureOffered) }
        set { defaults.set(newValue, forKey: PrefKey.folderStructureOffered) }
    }

    public static var scraperLanguage: String { defaults.string(forKey: PrefKey.scraperLanguage) ?? "en" }
    public static var scraperRegion: String { defaults.string(forKey: PrefKey.scraperRegion) ?? "eu" }
    public static var scraperUsername: String { defaults.string(forKey: PrefKey.scraperUsername) ?? "" }
    public static var autoScrape: Bool { defaults.bool(forKey: PrefKey.autoScrape) }
    public static var integerScaling: Bool { defaults.bool(forKey: PrefKey.integerScaling) }
    public static var volume: Double { defaults.double(forKey: PrefKey.volume) }
    public static var pauseInBackground: Bool { defaults.bool(forKey: PrefKey.pauseInBackground) }
    public static var autosaveOnQuit: Bool { defaults.bool(forKey: PrefKey.autosaveOnQuit) }
    public static var periodicAutosave: Bool { defaults.bool(forKey: PrefKey.periodicAutosave) }
    public static var resumeAutomatically: Bool { defaults.bool(forKey: PrefKey.resumeAutomatically) }
    public static var stickDeadZone: Float { Float(defaults.double(forKey: PrefKey.stickDeadZone)) }
    /// Times normal speed; 0 is as fast as possible.
    public static var fastForwardSpeed: Double { defaults.double(forKey: PrefKey.fastForwardSpeed) }
    public static var rewindEnabled: Bool { defaults.bool(forKey: PrefKey.rewindEnabled) }
    /// Megabytes of memory for rewinding.
    public static var rewindBufferSize: Int { defaults.integer(forKey: PrefKey.rewindBufferSize) }
    public static var runAheadFrames: Int { defaults.integer(forKey: PrefKey.runAheadFrames) }
    /// Frames a turbo button stays pressed and released.
    public static var turboRate: Int { max(1, defaults.integer(forKey: PrefKey.turboRate)) }
    public static var rumble: Bool { defaults.bool(forKey: PrefKey.rumble) }
    public static var bezel: BezelStyle { BezelStyle(rawValue: defaults.string(forKey: PrefKey.bezel) ?? "") ?? .none }
    public static var achievementsEnabled: Bool { defaults.bool(forKey: PrefKey.achievementsEnabled) }
    public static var achievementsUsername: String { defaults.string(forKey: PrefKey.achievementsUsername) ?? "" }
    public static var achievementsHardcore: Bool { defaults.bool(forKey: PrefKey.achievementsHardcore) }
    public static var achievementsShowsProgress: Bool { defaults.bool(forKey: PrefKey.achievementsShowsProgress) }
    public static var standaloneFullscreen: Bool { defaults.bool(forKey: PrefKey.standaloneFullscreen) }

    /// The user's collections in sidebar order, including empty ones.
    public static var collections: [String] {
        get { defaults.stringArray(forKey: PrefKey.collections) ?? [] }
        set { defaults.set(newValue, forKey: PrefKey.collections) }
    }

    public static func coreChoice(for systemID: String) -> String? {
        defaults.string(forKey: PrefKey.coreChoice(systemID))
    }

    public static func setCoreChoice(_ coreID: String?, for systemID: String) {
        defaults.set(coreID, forKey: PrefKey.coreChoice(systemID))
    }

    /// User-changed core option values, persisted per core.
    public static func coreOptions(for coreID: String) -> [String: String] {
        defaults.dictionary(forKey: PrefKey.coreOptions(coreID)) as? [String: String] ?? [:]
    }

    public static func setCoreOption(_ value: String, key: String, for coreID: String) {
        var options = coreOptions(for: coreID)
        options[key] = value
        defaults.set(options, forKey: PrefKey.coreOptions(coreID))
    }

    public static func resetCoreOptions(for coreID: String) {
        defaults.removeObject(forKey: PrefKey.coreOptions(coreID))
    }

    public static func rendererChoice(for coreID: String) -> RendererChoice {
        RendererChoice(rawValue: defaults.string(forKey: PrefKey.rendererChoice(coreID)) ?? "") ?? .automatic
    }

    public static func setRendererChoice(_ choice: RendererChoice, for coreID: String) {
        if choice == .automatic {
            defaults.removeObject(forKey: PrefKey.rendererChoice(coreID))
        } else {
            defaults.set(choice.rawValue, forKey: PrefKey.rendererChoice(coreID))
        }
    }

    // MARK: Backup

    /// Preferences a backup carries. Window state such as the last Settings
    /// tab stays behind; passwords live in the keychain and never get here.
    private static let backedUpKeys: Set<String> = [
        PrefKey.libraryFolders, PrefKey.scraperLanguage, PrefKey.scraperRegion, PrefKey.scraperUsername,
        PrefKey.autoScrape, PrefKey.videoFilter, PrefKey.integerScaling, PrefKey.volume, PrefKey.pauseInBackground,
        PrefKey.showFPS, PrefKey.gridSize, PrefKey.keyboardMapping, PrefKey.librarySort,
        PrefKey.autosaveOnQuit, PrefKey.periodicAutosave, PrefKey.resumeAutomatically,
        PrefKey.controllerMapping, PrefKey.turboButtons, PrefKey.hotkeys, PrefKey.portAssignments, PrefKey.stickDeadZone,
        PrefKey.collections, PrefKey.libraryViewMode, PrefKey.groupsVariants,
        PrefKey.fastForwardSpeed, PrefKey.rewindEnabled, PrefKey.rewindBufferSize, PrefKey.runAheadFrames,
        PrefKey.turboRate, PrefKey.rumble, PrefKey.bezel, PrefKey.achievementsEnabled, PrefKey.achievementsUsername,
        PrefKey.achievementsHardcore, PrefKey.achievementsShowsProgress, PrefKey.shaderFavorites,
        PrefKey.accentColor, PrefKey.customAccentColor,
    ]
    private static let backedUpPrefixes = ["coreChoice.", "coreOptions.", "hidGamepadMapping.", "inputProfile.", "rendererChoice.",
                                           "videoFilter."]

    private static func isBackedUp(_ key: String) -> Bool {
        backedUpKeys.contains(key) || backedUpPrefixes.contains { key.hasPrefix($0) }
    }

    /// The backed-up preferences as a property list.
    public static func backupData() throws -> Data {
        let values = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        let selected = values.filter { isBackedUp($0.key) }
        return try PropertyListSerialization.data(fromPropertyList: selected, format: .xml, options: 0)
    }

    /// Applies preferences from a backup and returns its library folders,
    /// which the caller adds to the current ones instead of replacing them.
    /// Keys a backup must not carry are ignored. A game's own settings move
    /// to the ID `gameIDs` restores it as; those of games the backup doesn't
    /// restore are dropped. When several of the backup's games become one,
    /// the setting of the first of them in `precedence` wins.
    @discardableResult
    public static func restore(fromBackup data: Data, gameIDs: [UUID: UUID], precedence: [UUID] = [],
                               into store: UserDefaults = .standard) -> [URL] {
        guard let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
        let rank = Dictionary(precedence.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var gameFilters: [UUID: (order: (Int, String), value: Any)] = [:]
        var folders: [URL] = []
        for (key, value) in values where isBackedUp(key) {
            if key == PrefKey.libraryFolders {
                folders = (value as? [String] ?? []).map { URL(filePath: $0, directoryHint: .isDirectory) }
            } else if key == PrefKey.collections {
                // Like the games, collections are added to the current ones.
                let current = store.stringArray(forKey: PrefKey.collections) ?? []
                store.set(current + (value as? [String] ?? []).filter { !current.contains($0) }, forKey: PrefKey.collections)
            } else if key.hasPrefix(PrefKey.gameVideoFilterPrefix) {
                guard let id = UUID(uuidString: String(key.dropFirst(PrefKey.gameVideoFilterPrefix.count))),
                      let restored = gameIDs[id] else { continue }
                // Games without a rank go by ID, never by dictionary order.
                let order = (rank[id] ?? Int.max, id.uuidString)
                if let chosen = gameFilters[restored], chosen.order < order { continue }
                gameFilters[restored] = (order, value)
            } else {
                store.set(value, forKey: key)
            }
        }
        for (id, filter) in gameFilters { store.set(filter.value, forKey: PrefKey.gameVideoFilter(id)) }
        return folders
    }
}