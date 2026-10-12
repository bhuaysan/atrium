// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Security

/// Atrium was called Ursprung until October 2026. On the first launch under
/// the new name this takes over what Ursprung left behind: its data folder,
/// its preferences and its keychain items. Nothing that already exists under
/// the new name is replaced, and the games folder the user made (`~/Ursprung`)
/// stays where it is: the preferences keep pointing at it.
///
/// `AppPaths.root` runs it, as every access to the app's data goes through it.
public nonisolated enum LegacyName {
    public static let bundleIdentifier = "io.github.bhuaysan.Ursprung"
    public static let folderName = "Ursprung"
    /// Set in the new preferences once they were taken over.
    public static let migratedKey = "migratedFromUrsprung"

    public static func migrate(dataFolder root: URL) {
        let fileManager = FileManager.default
        moveDataFolder(from: root.deletingLastPathComponent().appending(path: folderName, directoryHint: .isDirectory),
                       to: root)
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? fileManager.removeItem(at: caches.appending(path: folderName, directoryHint: .isDirectory))
        if let domain = Bundle.main.bundleIdentifier {
            migratePreferences(from: UserDefaults.standard.persistentDomain(forName: bundleIdentifier),
                               to: .standard, domain: domain)
        }
        moveKeychainItems(from: bundleIdentifier, to: Keychain.service)
    }

    /// Renames `legacy` to `root` unless `root` already exists.
    public static func moveDataFolder(from legacy: URL, to root: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacy.path(percentEncoded: false)),
              !fileManager.fileExists(atPath: root.path(percentEncoded: false)) else { return }
        try? fileManager.moveItem(at: legacy, to: root)
    }

    /// Copies the old preferences that `domain` (the one `defaults` writes
    /// to) does not have yet, once.
    public static func migratePreferences(from legacy: [String: Any]?, to defaults: UserDefaults, domain: String) {
        guard let legacy, !defaults.bool(forKey: migratedKey) else { return }
        let current = defaults.persistentDomain(forName: domain) ?? [:]
        for (key, value) in legacy where current[key] == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: migratedKey)
    }

    /// Moves the ScreenScraper password and RetroAchievements tokens to the
    /// new service name, one at a time: macOS may ask whether Atrium may use
    /// an item, and one the user denies stays behind without holding back the
    /// others. It is tried again on the next launch.
    public static func moveKeychainItems(from legacyService: String, to service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return }
        for account in items.compactMap({ $0[kSecAttrAccount as String] as? String }) {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: legacyService,
                kSecAttrAccount as String: account,
            ]
            SecItemUpdate(item as CFDictionary, [kSecAttrService as String: service] as CFDictionary)
        }
    }
}
