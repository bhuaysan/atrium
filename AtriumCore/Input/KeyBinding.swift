// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A key bound to an input or a hotkey, with the label it had on the
/// keyboard layout in use when it was bound.
public nonisolated struct KeyBinding: Codable, Hashable, Sendable {
    public var key: KeyboardKey
    public var label: String

    public init(key: KeyboardKey, label: String) {
        self.key = key
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case key, label
        /// Before October 2026: the macOS virtual key code.
        case keyCode
    }

    /// Reads bindings saved before keys were platform-neutral too (in the
    /// preferences, a game's controls or a backup); they are saved in the
    /// new form the next time.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        if let key = try container.decodeIfPresent(KeyboardKey.self, forKey: .key) {
            self.key = key
        } else {
            let keyCode = try container.decode(UInt16.self, forKey: .keyCode)
            guard let key = KeyboardKey(macKeyCode: keyCode) else {
                throw DecodingError.dataCorruptedError(forKey: .keyCode, in: container,
                                                       debugDescription: "Unknown macOS key code \(keyCode)")
            }
            self.key = key
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(label, forKey: .label)
    }
}
