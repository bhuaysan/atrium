// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Where Atrium keeps the data a backup contains.
public nonisolated struct DataLocations: Sendable {
    public var saves: URL
    public var states: URL
    public var media: URL
    /// Screenshots, manuals, patches and cheats (`GameExtras`).
    public var extras: URL
    /// Bezel images, one per system.
    public var bezels: URL
    /// The user's own shader presets (not the downloaded pack).
    public var shaders: URL

    public static var standard: DataLocations {
        DataLocations(saves: AppPaths.saves, states: AppPaths.states, media: AppPaths.media, extras: AppPaths.extras,
                      bezels: AppPaths.bezels, shaders: AppPaths.userShaders)
    }
}

/// One game of the library as written to a backup.
public nonisolated struct GameRecord: Codable, Sendable, Hashable {
    public var id: UUID
    public var path: String
    public var systemID: String
    public var title: String
    public var fileName: String
    public var fileSize: Int64
    public var crc32: String?
    public var fileModified: Date?
    public var dateAdded: Date
    public var lastPlayed: Date?
    public var playCount: Int
    public var playTime: Double
    public var isFavorite: Bool
    public var coreID: String?
    public var missingSince: Date?
    public var scrapeState: String
    public var screenScraperID: String?
    public var overview: String?
    public var developer: String?
    public var publisher: String?
    public var genre: String?
    public var releaseDate: String?
    public var players: String?
    public var rating: Double?
    public var boxArtFile: String?
    public var screenshotFile: String?
    public var titleScreenFile: String?
    public var logoFile: String?
    public var fanartFile: String?
    // Added with schema version 3; optional so older backups still decode.
    public var systemOverride: String?
    public var lockedFields: String?
    public var isHidden: Bool?
    public var coreOptions: Data?
    public var inputProfile: Data?
    // Added with schema version 4.
    public var collections: [String]?
    public var playStatus: String?
    public var isPreferredVariant: Bool?

    public init(id: UUID, path: String, systemID: String, title: String, fileName: String, fileSize: Int64,
                crc32: String? = nil, fileModified: Date? = nil, dateAdded: Date, lastPlayed: Date? = nil,
                playCount: Int, playTime: Double, isFavorite: Bool, coreID: String? = nil, missingSince: Date? = nil,
                scrapeState: String, screenScraperID: String? = nil, overview: String? = nil, developer: String? = nil,
                publisher: String? = nil, genre: String? = nil, releaseDate: String? = nil, players: String? = nil,
                rating: Double? = nil, boxArtFile: String? = nil, screenshotFile: String? = nil,
                titleScreenFile: String? = nil, logoFile: String? = nil, fanartFile: String? = nil,
                systemOverride: String? = nil, lockedFields: String? = nil, isHidden: Bool? = nil,
                coreOptions: Data? = nil, inputProfile: Data? = nil, collections: [String]? = nil,
                playStatus: String? = nil, isPreferredVariant: Bool? = nil) {
        self.id = id
        self.path = path
        self.systemID = systemID
        self.title = title
        self.fileName = fileName
        self.fileSize = fileSize
        self.crc32 = crc32
        self.fileModified = fileModified
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.playCount = playCount
        self.playTime = playTime
        self.isFavorite = isFavorite
        self.coreID = coreID
        self.missingSince = missingSince
        self.scrapeState = scrapeState
        self.screenScraperID = screenScraperID
        self.overview = overview
        self.developer = developer
        self.publisher = publisher
        self.genre = genre
        self.releaseDate = releaseDate
        self.players = players
        self.rating = rating
        self.boxArtFile = boxArtFile
        self.screenshotFile = screenshotFile
        self.titleScreenFile = titleScreenFile
        self.logoFile = logoFile
        self.fanartFile = fanartFile
        self.systemOverride = systemOverride
        self.lockedFields = lockedFields
        self.isHidden = isHidden
        self.coreOptions = coreOptions
        self.inputProfile = inputProfile
        self.collections = collections
        self.playStatus = playStatus
        self.isPreferredVariant = isPreferredVariant
    }

    public var saveBaseName: String { (fileName as NSString).deletingPathExtension }
}

/// `manifest.json`: identifies a backup and lists every file in it, so an
/// incomplete or damaged backup is noticed before anything is restored.
public nonisolated struct BackupManifest: Codable, Sendable {
    public static let formatName = "atrium-backup"
    /// Backups made while the app was called Ursprung.
    public static let legacyFormatNames: Set<String> = ["ursprung-backup"]
    public static let currentVersion = 1

    public struct Entry: Codable, Sendable, Hashable {
        public var path: String
        public var size: Int64
    }

    public var format = BackupManifest.formatName
    public var version = BackupManifest.currentVersion
    public var created: Date
    public var appVersion: String
    public var gameCount: Int
    public var files: [Entry]
}

/// A backup is a zip archive with one folder:
///
///     Atrium Backup/
///       manifest.json    format, version, date and every file with its size
///       library.json     the games (`GameRecord`)
///       settings.plist   preferences (no passwords: those stay in the keychain)
///       Saves/           battery saves and core save folders
///       States/          save states with their manifests
///       Media/           artwork
///       Extras/          screenshots, manuals, ROM patches and cheats per game
///       Bezels/          bezel images per system
///       Shaders/         the user's own shader presets (`Shaders/User/`)
///
/// BIOS files, cores and the downloaded shader pack are not included. See docs/SAVES.md.
public nonisolated enum Backup {
    public static let folderName = "Atrium Backup"

    public enum BackupError: LocalizedError {
        case notABackup
        case newerVersion
        case incomplete(missing: Int)
        case damaged(Error)

        public var errorDescription: String? {
            switch self {
            case .notABackup: String(localized: "The file is not an Atrium backup.", bundle: .module)
            case .newerVersion: String(localized: "The backup was made by a newer version of Atrium. Update Atrium to restore it.", bundle: .module)
            case .incomplete(let missing): String(localized: "The backup is incomplete: \(missing) files are missing or have the wrong size. Nothing was restored.", bundle: .module)
            case .damaged(let error): String(localized: "The backup is damaged. Nothing was restored. \(error.localizedDescription)", bundle: .module)
            }
        }
    }

    // MARK: Creating

    /// Writes a backup of `records`, `settings` and the data folders to
    /// `destination`. The archive is assembled next to the destination and
    /// only replaces it when complete.
    public static func create(records: [GameRecord], settings: Data, locations: DataLocations, destination: URL,
                              appVersion: String, created: Date = .now) throws {
        let fileManager = FileManager.default
        let staging = fileManager.temporaryDirectory.appending(path: "AtriumBackup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: staging) }
        let root = staging.appending(path: folderName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        try recordEncoder.encode(records).write(to: root.appending(path: "library.json"))
        try settings.write(to: root.appending(path: "settings.plist"))
        for (name, source) in [("Saves", locations.saves), ("States", locations.states), ("Media", locations.media),
                               ("Extras", locations.extras), ("Bezels", locations.bezels), ("Shaders", locations.shaders)]
        where fileManager.fileExists(atPath: source.path(percentEncoded: false)) {
            // Clones on APFS: instant and without extra space.
            try fileManager.copyItem(at: source, to: root.appending(path: name, directoryHint: .isDirectory))
        }
        let entries = FileMerge.files(below: root)
            .filter { $0.components.last != ".DS_Store" }
            .map { file in
                BackupManifest.Entry(path: file.components.joined(separator: "/"),
                                     size: Int64((try? file.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0))
            }
        let manifest = BackupManifest(created: created, appVersion: appVersion, gameCount: records.count, files: entries)
        try encoder.encode(manifest).write(to: root.appending(path: "manifest.json"))

        try zip(root, to: destination)
    }

    /// Zips `folder` (the archive contains the folder itself) into `destination`.
    private static func zip(_ folder: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let partial = destination.deletingLastPathComponent().appending(path: ".\(destination.lastPathComponent).partial")
        try? fileManager.removeItem(at: partial)
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { archive in
            do { try fileManager.copyItem(at: archive, to: partial) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError {
            try? fileManager.removeItem(at: partial)
            throw error
        }
        do {
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: partial)
            } else {
                try fileManager.moveItem(at: partial, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: partial)
            throw error
        }
    }

    // MARK: Opening

    /// An extracted, verified backup. `remove()` deletes the extracted files.
    public struct Contents: Sendable {
        public let manifest: BackupManifest
        public let records: [GameRecord]
        public let settings: Data?
        /// The extracted backup folder (with manifest.json).
        public let root: URL
        /// The temporary folder that holds `root`.
        public let temporary: URL

        public var batterySaveCount: Int { count(in: "Saves") { _ in true } }
        public var stateCount: Int { count(in: "States") { $0.hasSuffix(".state") || $0.hasSuffix(".p2s") } }

        public func remove() {
            try? FileManager.default.removeItem(at: temporary)
        }

        private func count(in folder: String, where include: (String) -> Bool) -> Int {
            manifest.files.filter { $0.path.hasPrefix(folder + "/") && include($0.path) }.count
        }
    }

    /// Extracts and checks the backup at `archive`. Throws when it is not a
    /// backup, comes from a newer version, or misses or garbles any file it
    /// lists; nothing has been restored at that point.
    public static func open(_ archive: URL) throws -> Contents {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory.appending(path: "AtriumRestore-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            let zip: ZipArchive
            do { zip = try ZipArchive(url: archive) } catch { throw BackupError.notABackup }
            guard zip.files.contains(where: { $0.fileName == "manifest.json" }) else { throw BackupError.notABackup }
            do { try zip.extractAll(to: temporary) } catch { throw BackupError.damaged(error) }

            guard let root = manifestFolder(in: temporary),
                  let manifest = try? decoder.decode(BackupManifest.self, from: Data(contentsOf: root.appending(path: "manifest.json"))),
                  manifest.format == BackupManifest.formatName || BackupManifest.legacyFormatNames.contains(manifest.format)
            else { throw BackupError.notABackup }
            guard manifest.version <= BackupManifest.currentVersion else { throw BackupError.newerVersion }

            let missing = manifest.files.filter { entry in
                let url = root.appending(path: entry.path)
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                return size.map(Int64.init) != entry.size
            }
            guard missing.isEmpty else { throw BackupError.incomplete(missing: missing.count) }

            let records: [GameRecord]
            do {
                records = try JSONDecoder().decode([GameRecord].self, from: Data(contentsOf: root.appending(path: "library.json")))
            } catch {
                throw BackupError.damaged(error)
            }
            let settings = try? Data(contentsOf: root.appending(path: "settings.plist"))
            return Contents(manifest: manifest, records: records, settings: settings, root: root, temporary: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    /// The folder with manifest.json: the extraction folder or its one sub folder.
    private static func manifestFolder(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.appending(path: "manifest.json").path(percentEncoded: false)) { return directory }
        let children = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return children.first { fileManager.fileExists(atPath: $0.appending(path: "manifest.json").path(percentEncoded: false)) }
    }

    // MARK: Restoring

    /// What the library knows about a game, to match backup records against.
    public struct ExistingGame: Sendable {
        public let id: UUID
        public let path: String
        public let systemID: String
        public let crc32: String?
        public let fileName: String
        public let fileSize: Int64

        public init(id: UUID, path: String, systemID: String, crc32: String?, fileName: String, fileSize: Int64) {
            self.id = id
            self.path = path
            self.systemID = systemID
            self.crc32 = crc32
            self.fileName = fileName
            self.fileSize = fileSize
        }
    }

    /// Where a backup record goes.
    public struct Target: Sendable, Equatable {
        /// The library entry that receives the record's data.
        public let id: UUID
        /// True when the record becomes a new library entry.
        public let isNew: Bool
    }

    /// Matches every record to a game of the library: the same entry (ID),
    /// the same file (path), or the same game by unique checksum or unique
    /// file name and size. Unmatched records become new entries, keeping their
    /// ID where it is free.
    public static func plan(records: [GameRecord], existing: [ExistingGame]) -> [UUID: Target] {
        var available = existing
        let existingIDs = Set(existing.map(\.id))
        let ownerOfPath = Dictionary(existing.map { ($0.path, $0.id) }, uniquingKeysWith: { first, _ in first })
        var plan: [UUID: Target] = [:]

        func claim(_ predicate: (ExistingGame) -> Bool, unique: Bool) -> UUID? {
            let found = available.filter(predicate)
            guard let first = found.first, !unique || found.count == 1 else { return nil }
            available.removeAll { $0.id == first.id }
            return first.id
        }

        var unmatched: [GameRecord] = []
        for record in records {
            if let id = claim({ $0.id == record.id }, unique: false) ?? claim({ $0.path == record.path }, unique: false) {
                plan[record.id] = Target(id: id, isNew: false)
            } else {
                unmatched.append(record)
            }
        }
        for record in unmatched {
            let crc = record.crc32
            let id = crc.flatMap { crc in
                claim({ $0.systemID == record.systemID && $0.crc32?.caseInsensitiveCompare(crc) == .orderedSame }, unique: true)
            } ?? claim({ $0.systemID == record.systemID && $0.fileName == record.fileName && $0.fileSize == record.fileSize }, unique: true)
            if let id {
                plan[record.id] = Target(id: id, isNew: false)
            } else if let owner = ownerOfPath[record.path] {
                // The file is in the library under an entry that another record
                // already claimed; both records add to it.
                plan[record.id] = Target(id: owner, isNew: false)
            } else {
                plan[record.id] = Target(id: existingIDs.contains(record.id) ? UUID() : record.id, isNew: true)
            }
        }
        return plan
    }

    /// The order in which the records' own settings count when several join
    /// one game: the game's own record (the same ID) first, then the backup's
    /// order.
    public static func settingsPrecedence(records: [GameRecord], plan: [UUID: Target]) -> [UUID] {
        let own = records.filter { plan[$0.id]?.id == $0.id }
        return (own + records.filter { plan[$0.id]?.id != $0.id }).map(\.id)
    }

    /// A battery save that has to take the name of the game it joins.
    public struct Rename: Sendable {
        public let systemID: String
        public let recordID: UUID
        public let from: String
        public let to: String

        public init(systemID: String, recordID: UUID, from: String, to: String) {
            self.systemID = systemID
            self.recordID = recordID
            self.from = from
            self.to = to
        }
    }

    /// Restores the backup's files for `plan`. Saves and states are merged
    /// without losing any file (see `FileMerge`); artwork only fills in what
    /// is missing. The extracted files are moved, not copied.
    public static func restoreFiles(of contents: Contents, plan: [UUID: Target], renames: [Rename],
                                    locations: DataLocations, now: Date = .now) throws -> FileMerge.Report {
        let fileManager = FileManager.default
        let ids = Dictionary(plan.map { ($0.key.uuidString, $0.value.id.uuidString) }, uniquingKeysWith: { first, _ in first })
        let mapComponent = { (component: String) in ids[component] ?? component }

        // A save named after the record's file takes the name of the game it joins.
        for rename in renames where rename.from != rename.to {
            let folder = contents.root.appending(path: "Saves").appending(path: rename.systemID)
                .appending(path: rename.recordID.uuidString, directoryHint: .isDirectory)
            for ext in ["srm", "rtc"] {
                let source = folder.appending(path: "\(rename.from).\(ext)")
                let target = folder.appending(path: "\(rename.to).\(ext)")
                if fileManager.fileExists(atPath: source.path(percentEncoded: false)),
                   !fileManager.fileExists(atPath: target.path(percentEncoded: false)) {
                    try fileManager.moveItem(at: source, to: target)
                }
            }
        }

        let labels = FileMerge.Labels(existing: String(localized: "before restore \(FileMerge.stamp(now))", bundle: .module),
                                      incoming: String(localized: "from backup \(FileMerge.stamp(contents.manifest.created))", bundle: .module))
        var report = FileMerge.Report()
        for (name, destination) in [("Saves", locations.saves), ("States", locations.states), ("Extras", locations.extras)] {
            let source = contents.root.appending(path: name, directoryHint: .isDirectory)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            report = report + (try FileMerge.mergeDirectory(source, into: destination, moving: true, labels: labels,
                                                            mapComponent: mapComponent))
        }
        // Artwork, bezel images and shaders only fill in what is missing.
        for (name, destination) in [("Media", locations.media), ("Bezels", locations.bezels), ("Shaders", locations.shaders)] {
            let source = contents.root.appending(path: name, directoryHint: .isDirectory)
            for (file, components) in FileMerge.files(below: source) {
                var target = destination
                for component in components { target = target.appending(path: mapComponent(component)) }
                guard !fileManager.fileExists(atPath: target.path(percentEncoded: false)) else { continue }
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: file, to: target)
            }
        }
        return report
    }

    /// Dates as numbers: exact, so a restored modification date still equals the file's.
    private static var recordEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
