// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Translates keys into keys of an emulated computer keyboard (libretro
/// `RETROK_*` values). Keys map by position, like scancodes: the key left
/// of Return is the same key on every layout; the typed character travels
/// along for cores that want text.
public nonisolated enum EmulatedKeyboard {
    /// The libretro key for `key`, or nil.
    public static func retroKey(for key: KeyboardKey) -> UInt32? {
        table[key]
    }

    private static let table: [KeyboardKey: UInt32] = [
        // Letters (ANSI positions)
        .keyA: 97, .keyB: 98, .keyC: 99, .keyD: 100, .keyE: 101, .keyF: 102, .keyG: 103, .keyH: 104, .keyI: 105,
        .keyJ: 106, .keyK: 107, .keyL: 108, .keyM: 109, .keyN: 110, .keyO: 111, .keyP: 112, .keyQ: 113, .keyR: 114,
        .keyS: 115, .keyT: 116, .keyU: 117, .keyV: 118, .keyW: 119, .keyX: 120, .keyY: 121, .keyZ: 122,
        // Digits
        .digit0: 48, .digit1: 49, .digit2: 50, .digit3: 51, .digit4: 52, .digit5: 53, .digit6: 54, .digit7: 55,
        .digit8: 56, .digit9: 57,
        // Punctuation
        .minus: 45, .equal: 61, .bracketLeft: 91, .bracketRight: 93, .backslash: 92, .semicolon: 59, .quote: 39,
        .comma: 44, .period: 46, .slash: 47, .backquote: 96, .intlBackslash: 323,
        // Editing and whitespace
        .enter: 13, .tab: 9, .space: 32, .backspace: 8, .escape: 27, .delete: 127, .insert: 277,
        // Navigation
        .arrowUp: 273, .arrowDown: 274, .arrowRight: 275, .arrowLeft: 276, .home: 278, .end: 279, .pageUp: 280,
        .pageDown: 281,
        // Function keys
        .f1: 282, .f2: 283, .f3: 284, .f4: 285, .f5: 286, .f6: 287, .f7: 288, .f8: 289, .f9: 290, .f10: 291,
        .f11: 292, .f12: 293, .f13: 294, .f14: 295, .f15: 296,
        // Keypad
        .numpad0: 256, .numpad1: 257, .numpad2: 258, .numpad3: 259, .numpad4: 260, .numpad5: 261, .numpad6: 262,
        .numpad7: 263, .numpad8: 264, .numpad9: 265, .numpadDecimal: 266, .numpadDivide: 267, .numpadMultiply: 268,
        .numpadSubtract: 269, .numpadAdd: 270, .numpadEnter: 271, .numpadEqual: 272, .numLock: 12,
        // Modifiers
        .capsLock: 301, .shiftRight: 303, .shiftLeft: 304, .controlRight: 305, .controlLeft: 306, .altRight: 307,
        .altLeft: 308, .metaRight: 309, .metaLeft: 310,
    ]
}
