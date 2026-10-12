// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Atrium
@testable import AtriumCore

/// What Atrium takes over from the time it was called Ursprung.
@Suite("Legacy name")
struct LegacyNameTests {
    @Test func dataFolderMovesUnlessTheNewOneExists() throws {
        let base = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appending(path: "Ursprung", directoryHint: .isDirectory)
        let root = base.appending(path: "Atrium", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: legacy.appending(path: "Saves"), withIntermediateDirectories: true)
        try Data("store".utf8).write(to: legacy.appending(path: "Library.store"))

        LegacyName.moveDataFolder(from: legacy, to: root)
        #expect(try Data(contentsOf: root.appending(path: "Library.store")) == Data("store".utf8))
        #expect(!FileManager.default.fileExists(atPath: legacy.path(percentEncoded: false)))

        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: legacy.appending(path: "Library.store"))
        LegacyName.moveDataFolder(from: legacy, to: root)
        #expect(try Data(contentsOf: root.appending(path: "Library.store")) == Data("store".utf8))
        #expect(FileManager.default.fileExists(atPath: legacy.path(percentEncoded: false)))
    }

    @Test func preferencesAreTakenOverOnceWithoutReplacingNewOnes() throws {
        let suite = "AtriumTests.LegacyName.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("new", forKey: "kept")

        LegacyName.migratePreferences(from: ["kept": "old", "taken": 3], to: defaults, domain: suite)
        #expect(defaults.string(forKey: "kept") == "new")
        #expect(defaults.integer(forKey: "taken") == 3)

        defaults.removeObject(forKey: "taken")
        LegacyName.migratePreferences(from: ["taken": 3], to: defaults, domain: suite)
        #expect(defaults.object(forKey: "taken") == nil)
    }

    @Test func ursprungBackupsCanBeRestored() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appending(path: "Ursprung Backup", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: folder.appending(path: "library.json"))
        var manifest = BackupManifest(created: .now, appVersion: "0.1.0", gameCount: 0,
                                      files: [.init(path: "library.json", size: 2)])
        manifest.format = "ursprung-backup"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: folder.appending(path: "manifest.json"))
        let archive = root.appending(path: "Backup.zip")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/zip")
        process.currentDirectoryURL = root
        process.arguments = ["-qr", archive.path(percentEncoded: false), "Ursprung Backup"]
        try process.run()
        process.waitUntilExit()

        let contents = try Backup.open(archive)
        defer { try? FileManager.default.removeItem(at: contents.temporary) }
        #expect(contents.records.isEmpty)
    }

    @Test func ursprungShaderFramesKeepTheirAspectRatio() {
        #expect(ShaderFrameStore.aspectRatio(inDescription: "Ursprung shader frame; aspect 1.333333") == 1.333333)
        #expect(ShaderFrameStore.aspectRatio(inDescription: ShaderFrameStore.description(aspectRatio: 1.5)) == 1.5)
        #expect(ShaderFrameStore.aspectRatio(inDescription: "Other app; aspect 1.5") == nil)
    }
}
