// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore
import Foundation

/// A standalone emulator opened with its own window on Atrium's data
/// folder, for the settings Atrium does not manage (graphics,
/// achievements; Q5). The settings Atrium manages are written first and
/// again before every game. `EmulationSession` owns it and tells it when a
/// game uses the emulator.
@Observable
final class StandaloneSettingsWindow {
    /// The emulator whose own window is open or opening.
    private(set) var emulatorID: String?
    @ObservationIgnored private var process: ExternalSession?
    @ObservationIgnored private var opening: Task<Void, any Error>?

    /// Opens the window; `request` installs the emulator and describes how
    /// it starts. Brings an open window to the front. Does nothing while a
    /// game uses the emulator or a window is opening.
    func open(_ emulator: StandaloneEmulator, outputLog: URL, isEmulatorInUse: @escaping @MainActor () -> Bool,
              request: @escaping @MainActor () async throws -> ARMSX2Launch.Request) async throws {
        if let process, process.isRunning {
            return process.activate()
        }
        guard !isEmulatorInUse(), opening == nil else { return }
        emulatorID = emulator.id
        let opening = Task { try await start(outputLog: outputLog, isEmulatorInUse: isEmulatorInUse, request: request) }
        self.opening = opening
        defer { self.opening = nil }
        do {
            try await opening.value
        } catch {
            emulatorID = nil
            throw error
        }
    }

    private func start(outputLog: URL, isEmulatorInUse: @MainActor () -> Bool,
                       request makeRequest: @MainActor () async throws -> ARMSX2Launch.Request) async throws {
        let request = try await makeRequest()
        let launch: ARMSX2Launch
        let process: ExternalSession
        do {
            launch = try await ARMSX2Launch.prepareInBackground(request)
            // A game launch waits for this, then writes its own settings.
            guard !isEmulatorInUse() else {
                try? FileManager.default.removeItem(at: request.pineFolder)
                emulatorID = nil
                return
            }
            try launch.writeSharedFiles()
            process = try ExternalSession(executable: launch.executable, arguments: launch.arguments,
                                          environment: launch.environment, output: outputLog)
        } catch {
            try? FileManager.default.removeItem(at: request.pineFolder)
            throw error
        }
        let pine = PINEClient(socket: launch.pineSocket)
        process.onExit = { [weak self, weak process] _ in
            pine.removeSocketFolder()
            guard let self, self.process === process else { return }
            self.process = nil
            emulatorID = nil
        }
        self.process = process
    }

    /// Quits the window, which saves its settings as it goes. One that is
    /// still opening is waited for: it writes the settings too.
    func close() async {
        _ = try? await opening?.value
        guard let process else { return }
        await process.stop()
        if self.process === process {
            self.process = nil
            emulatorID = nil
        }
    }

    /// Quits the window before the app exits.
    func stopAndWait() {
        process?.stopAndWait()
    }
}
