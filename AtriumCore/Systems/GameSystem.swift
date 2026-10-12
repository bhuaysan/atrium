// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An emulator that can run one or more systems: usually a libretro core,
/// downloaded from the libretro buildbot on first use (see `CoreManager`),
/// or a standalone emulator that runs as its own process.
public nonisolated struct CoreDefinition: Sendable, Hashable, Identifiable {
    /// Buildbot base name, e.g. `snes9x` for `snes9x_libretro.dylib`; for a
    /// standalone emulator its `StandaloneEmulator.id`.
    public let id: String
    public let name: String
    /// Frontend defaults for core options (user choices override these).
    public var optionDefaults: [String: String] = [:]
    /// The graphics API Atrium asks the core for unless the user picks
    /// another one (Settings › Cores).
    public var renderer: HardwareRenderer = .opengl
    /// Option defaults for when the core renders with Vulkan, on top of
    /// `optionDefaults`; nil for cores without a Vulkan renderer.
    public var vulkanOptionDefaults: [String: String]? = nil
    /// Optional asset archive extracted into the system directory
    /// (e.g. PPSSPP fonts & shaders).
    public var systemAssets: URL? = nil
    public var experimental: Bool = false
    public var backend: CoreBackend = .libretro

    /// The libretro dylib; only meaningful for `.libretro`.
    public var fileName: String { "\(id)_libretro.dylib" }

    public var standalone: StandaloneEmulator? {
        if case .standalone(let emulator) = backend { emulator } else { nil }
    }

    public var isLibretro: Bool { standalone == nil }

    /// Whether the core can render with Vulkan, so the user can choose.
    public var supportsVulkan: Bool { vulkanOptionDefaults != nil }

    /// The frontend defaults for the core rendering with `renderer`.
    public func optionDefaults(for renderer: HardwareRenderer) -> [String: String] {
        guard renderer == .vulkan, let vulkanOptionDefaults else { return optionDefaults }
        return optionDefaults.merging(vulkanOptionDefaults) { $1 }
    }

    /// The renderer the user's `choice` asks for, whether or not this Mac
    /// can provide it.
    public func wantedRenderer(for choice: RendererChoice) -> HardwareRenderer {
        guard supportsVulkan else { return .opengl }
        return switch choice {
        case .automatic: renderer
        case .vulkan: .vulkan
        case .opengl: .opengl
        }
    }

    /// The renderer a game of this core starts with: the wanted one, or
    /// OpenGL where there is no Vulkan.
    public func renderer(for choice: RendererChoice, vulkanAvailable: Bool) -> HardwareRenderer {
        let wanted = wantedRenderer(for: choice)
        return wanted == .vulkan && !vulkanAvailable ? .opengl : wanted
    }
}

/// A graphics API Atrium gives cores that render on the GPU. Vulkan runs
/// through MoltenVK (docs/VULKAN_PLAN.md).
public nonisolated enum HardwareRenderer: String, Sendable, Hashable, CaseIterable {
    case opengl
    case vulkan

    /// Product names, the same in every language.
    public var name: String {
        switch self {
        case .opengl: "OpenGL"
        case .vulkan: "Vulkan"
        }
    }
}

/// How Atrium runs a core.
public nonisolated enum CoreBackend: Sendable, Hashable {
    /// Loaded in-process and presented in the player window.
    case libretro
    /// A separate application Atrium downloads, configures and launches.
    case standalone(StandaloneEmulator)
}

/// An emulator that runs as its own process with its own window (see
/// docs/STANDALONE_PLAN.md). Atrium pins one tested release.
public nonisolated struct StandaloneEmulator: Sendable, Hashable, Identifiable {
    public nonisolated struct Release: Sendable, Hashable {
        /// Release tag on GitHub, e.g. `nightly-20261006`.
        public let tag: String
        public let assetName: String
        /// SHA-256 of the asset, lower-case hex.
        public let sha256: String
        /// Source commit; also the installation folder name.
        public let commit: String
    }

    public let id: String
    public let name: String
    /// GitHub `owner/repository` the release is downloaded from.
    public let repository: String
    public let release: Release
    /// Developer ID team the app must be signed by.
    public let teamIdentifier: String
    /// The executable inside the installed `.app`, relative to the bundle.
    public let executable: String
    /// Save state format version of the pinned release; states with another
    /// major version cannot be loaded. Installed versions record theirs
    /// (`EmulatorManager.saveStateVersion(of:)`): check against that one.
    public let saveStateVersion: UInt32

    public var downloadURL: URL {
        URL(string: "https://github.com/\(repository)/releases/download/\(release.tag)/\(release.assetName)")!
    }

    public var sourceURL: URL { URL(string: "https://github.com/\(repository)")! }
}

/// A folder in the system directory that must hold at least one BIOS dump
/// of a kind, under any file name — for systems whose dumps exist in many
/// versions (PlayStation 2).
public nonisolated struct BIOSFolder: Sendable, Hashable {
    public nonisolated enum Kind: Sendable, Hashable {
        case playStation2
    }

    /// Path relative to the system directory.
    public let path: String
    public let kind: Kind
    /// Cores that cannot start without a dump.
    public let requiredBy: Set<String>

    public func isRequired(forCore coreID: String) -> Bool {
        requiredBy.contains(coreID)
    }
}

/// A BIOS / firmware file expected in the libretro system directory.
public nonisolated struct BIOSFile: Sendable, Hashable, Identifiable {
    /// Path relative to the system directory (may contain a sub folder).
    public let fileName: String
    public let md5: String?
    public let required: Bool
    public var note: String? = nil
    /// Required files that share a group are alternatives, e.g. region
    /// variants: one of them suffices. Required files without a group are
    /// all needed.
    public var group: String? = nil
    /// Cores that need the file although `required` is false, e.g. the
    /// PlayStation cores without a built-in BIOS.
    public var requiredBy: Set<String> = []

    public var id: String { fileName }

    /// Whether `coreID` cannot start without this file (or its alternatives).
    public func isRequired(forCore coreID: String) -> Bool {
        required || requiredBy.contains(coreID)
    }
}

public nonisolated struct GameSystem: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable {
        case console, handheld, arcade, computer
    }

    /// Stable identifier stored in the library database.
    public let id: String
    public let name: String
    public let shortName: String
    public let manufacturer: String
    public let year: Int
    public let kind: Kind
    /// ScreenScraper `systemeid`.
    public let screenScraperID: Int
    /// Lower-case file extensions without dot.
    public let extensions: Set<String>
    /// Normalised folder names that identify this system (for ambiguous
    /// extensions such as .bin/.iso/.cue/.zip).
    public let folderAliases: Set<String>
    /// Available cores, the first one is the default.
    public let cores: [CoreDefinition]
    public var bios: [BIOSFile] = []
    public var biosFolder: BIOSFolder? = nil
    /// True for systems whose games ship as .zip sets (arcade) — archives are
    /// passed to the core as-is instead of being extracted.
    public var archivesAreNative: Bool = false
    /// Accent used for generated placeholder artwork.
    public var accent: UInt32 = 0x6E6E73
    /// Aspect ratio (width / height) of typical box art, used for grid cards.
    public var boxAspect: Double = 0.72

    public var defaultCore: CoreDefinition { cores[0] }

    /// Its folder in the folder structure, e.g. “Super Nintendo”.
    public var folderName: String { SystemCatalog.folderNames[id] ?? shortName }

    /// Whether ROM patches (IPS, UPS, BPS) can be applied to its games.
    public var supportsPatches: Bool { SystemCatalog.supportsPatches(self) }

    public func core(withID id: String?) -> CoreDefinition {
        cores.first { $0.id == id } ?? defaultCore
    }

    public static func == (lhs: GameSystem, rhs: GameSystem) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
