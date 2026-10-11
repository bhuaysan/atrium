// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension ARMSX2Launch.Request {
    /// What ARMSX2 is started with: `game` in Ursprung's folders for it, or
    /// without a game ARMSX2's own window and folders.
    init(app: URL, emulator: StandaloneEmulator, system: GameSystem, game: Game?, resume: Bool = false, state: URL? = nil,
         emulators: EmulatorManager, bios: BIOSManager) {
        // The metadata region, when the disc does not tell which BIOS it wants.
        let fallbackRegion: PS2BIOS.Region = switch Preferences.scraperRegion {
        case "us": .usa
        case "jp": .japan
        default: .europe
        }
        let dataFolder = emulators.dataFolder(for: emulator)
        self.init(
            app: app, executable: emulator.executable,
            dataFolder: dataFolder,
            logFile: emulators.logFolder(for: emulator).appending(path: "last-run.log"),
            pineFolder: ARMSX2Launch.newPINEFolder(in: URL(filePath: NSTemporaryDirectory())),
            game: game?.fileURL,
            biosFolder: AppPaths.system.appending(path: system.biosFolder?.path ?? "", directoryHint: .isDirectory),
            dumps: system.biosFolder.map(bios.dumps(in:)) ?? [],
            fallbackRegion: fallbackRegion,
            memoryCardFolder: game.map { PS2MemoryCard.folder(in: AppPaths.saves, systemID: system.id, gameID: $0.id) }
                ?? PCSX2Config.ownFolder("memcards", dataFolder: dataFolder),
            saveStateFolder: game.map { SaveStateStore.directory(in: AppPaths.states, gameID: $0.id, coreID: emulator.id) }
                ?? PCSX2Config.ownFolder("sstates", dataFolder: dataFolder),
            snapshotFolder: game.map { ScreenshotStore.directory(in: AppPaths.extras, gameID: $0.id) }
                ?? PCSX2Config.ownFolder("snaps", dataFolder: dataFolder),
            resume: resume,
            saveStateOnShutdown: Preferences.autosaveOnQuit,
            fullscreen: Preferences.standaloneFullscreen,
            controls: ARMSX2Controls(
                profile: InputProfile.resolved(gameProfile: game?.inputProfileData, systemID: system.id),
                hotkeys: .current, rumble: Preferences.rumble, deadZone: Preferences.stickDeadZone,
                keyNames: ARMSX2Keys.currentLayout()),
            saveStateVersion: emulators.saveStateVersion(of: emulator),
            stateFile: state)
    }
}

extension ARMSX2Launch {
    /// `prepare(_:environment:)` away from the main actor: it reads the game
    /// and BIOS files and writes into the data folder.
    @concurrent
    static func prepareInBackground(_ request: Request) async throws -> ARMSX2Launch {
        try prepare(request, environment: ProcessInfo.processInfo.environment)
    }
}

extension PINEClient {
    /// Removes the folder Ursprung made for the socket once the emulator is gone.
    func removeSocketFolder() {
        try? FileManager.default.removeItem(at: socket.deletingLastPathComponent())
    }
}
