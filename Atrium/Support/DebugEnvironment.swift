// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation

/// Development aids that debug builds read from `ATRIUM_*` environment
/// variables, for inspecting and driving the app without UI access (see the
/// debug-without-ui skill). The Objective-C side reads ATRIUM_CORE_LOG and
/// ATRIUM_VULKAN_LOG itself.
nonisolated enum DebugEnvironment {
    private static func value(_ name: String) -> String? {
        ProcessInfo.processInfo.environment["ATRIUM_\(name)"]
    }

    /// ATRIUM_SNAPSHOT_DIR: windows, the game's frame and the session state
    /// are written there regularly.
    static var snapshotDirectory: URL? {
        value("SNAPSHOT_DIR").map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    /// ATRIUM_AUTOPLAY=<title substring> starts a game on launch.
    static var autoplayQuery: String? { value("AUTOPLAY") }

    /// ATRIUM_SYSTEM=<system id> selects that system in the sidebar.
    static var systemID: String? { value("SYSTEM") }

    /// ATRIUM_FOLDER_SETUP=1 offers the folder structure as on the first launch.
    static var offersFolderSetup: Bool { value("FOLDER_SETUP") == "1" }

    /// ATRIUM_SELECT=<title substring>[|<title substring>…] selects one or several games.
    static var selectionQueries: [Substring]? { value("SELECT").map { $0.split(separator: "|") } }

    /// ATRIUM_SHADER_EDITOR=<preset:library/…|preset:user/…|system id|new> opens the shader editor.
    static var shaderEditorRequest: String? { value("SHADER_EDITOR") }

    /// ATRIUM_METADATA_ERROR=<message|quota> shows the activity footer's error row.
    static var metadataError: String? { value("METADATA_ERROR") }

    /// ATRIUM_SHADER=<filter|preset:library/…|preset:user/…> replaces the player's shader choice.
    static var shader: ShaderSelection? { value("SHADER").flatMap(ShaderSelection.init(rawValue:)) }

    /// ATRIUM_SHADER_PARAMS=NAME=value,… changes parameters of every preset that loads.
    static var shaderParameters: [(name: String, value: Float)] {
        (value("SHADER_PARAMS") ?? "").split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let value = Float(parts[1]) else { return nil }
            return (parts[0], value)
        }
    }

    /// ATRIUM_DEBUG_PLAY: a started game takes a screenshot, rewinds and
    /// fast-forwards, then the app quits.
    static var exercisesPlay: Bool { value("DEBUG_PLAY") != nil }

    /// ATRIUM_DEBUG_STATES: a started game saves and loads a state, then the app quits.
    static var exercisesStates: Bool { value("DEBUG_STATES") != nil }
}
#endif
