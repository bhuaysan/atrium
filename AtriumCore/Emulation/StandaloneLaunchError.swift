// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Why ARMSX2 is not started for a game. Every error ARMSX2 would report
/// itself opens a dialog, and dialogs crash it on macOS 27, so Atrium checks
/// what it can beforehand (docs/STANDALONE_PLAN.md, S5).
public nonisolated enum StandaloneLaunchError: LocalizedError {
    case gameUnreadable(name: String)
    /// A format the emulator does not read: an archive, a playlist, a sheet
    /// without a disc image it reads.
    case unsupportedArchive(name: String)
    case unsupportedPlaylist(name: String)
    case unsupportedFormat(name: String)
    case memoryCardReadOnly(URL)
    case folderNotWritable(URL)
    case settingsNotWritten(reason: String)
    case stateNotLoadable

    public var errorDescription: String? {
        switch self {
        case .gameUnreadable(let name):
            String(localized: "“\(name)” can't be read. Check its permissions in the Finder (Get Info › Sharing & Permissions), then try again.", bundle: .module)
        case .unsupportedArchive(let name):
            String(localized: "ARMSX2 can't start games from archives. Unpack “\(name)” in the Finder, then rescan.", bundle: .module)
        case .unsupportedPlaylist(let name):
            String(localized: "ARMSX2 can't switch the discs of a playlist. Delete “\(name)” to start each disc on its own, then rescan.", bundle: .module)
        case .unsupportedFormat(let name):
            String(localized: "ARMSX2 can't read “\(name)”. It starts ISO, BIN, IMG, MDF, CHD, CSO, ZSO and GZ disc images.", bundle: .module)
        case .memoryCardReadOnly(let url):
            String(localized: "The game's memory card is locked or read-only, so its saves couldn't be written: \(url.path(percentEncoded: false)).", bundle: .module)
        case .folderNotWritable(let url):
            String(localized: "Atrium can't write to “\(url.path(percentEncoded: false))”. Check the folder's permissions, then try again.", bundle: .module)
        case .settingsNotWritten(let reason):
            String(localized: "The emulator's settings couldn't be written. \(reason)", bundle: .module)
        case .stateNotLoadable:
            String(localized: "The save state can't be loaded. It is damaged, or it was saved by a version of ARMSX2 that this one can't read.", bundle: .module)
        }
    }
}
