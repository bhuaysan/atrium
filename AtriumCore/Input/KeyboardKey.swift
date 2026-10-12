// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A key by its position on the keyboard, whatever the layout prints on it:
/// the key left of X is `.keyZ` on a German keyboard too. Named like the
/// W3C UI Events `KeyboardEvent.code` values, which saved bindings store, so
/// they mean the same key on macOS and Linux.
public nonisolated enum KeyboardKey: String, CaseIterable, Codable, Hashable, Sendable {
    // Letters
    case keyA = "KeyA", keyB = "KeyB", keyC = "KeyC", keyD = "KeyD", keyE = "KeyE", keyF = "KeyF", keyG = "KeyG"
    case keyH = "KeyH", keyI = "KeyI", keyJ = "KeyJ", keyK = "KeyK", keyL = "KeyL", keyM = "KeyM", keyN = "KeyN"
    case keyO = "KeyO", keyP = "KeyP", keyQ = "KeyQ", keyR = "KeyR", keyS = "KeyS", keyT = "KeyT", keyU = "KeyU"
    case keyV = "KeyV", keyW = "KeyW", keyX = "KeyX", keyY = "KeyY", keyZ = "KeyZ"
    // Digits
    case digit0 = "Digit0", digit1 = "Digit1", digit2 = "Digit2", digit3 = "Digit3", digit4 = "Digit4"
    case digit5 = "Digit5", digit6 = "Digit6", digit7 = "Digit7", digit8 = "Digit8", digit9 = "Digit9"
    // Punctuation
    case minus = "Minus", equal = "Equal", bracketLeft = "BracketLeft", bracketRight = "BracketRight"
    case backslash = "Backslash", semicolon = "Semicolon", quote = "Quote", comma = "Comma", period = "Period"
    case slash = "Slash", backquote = "Backquote", intlBackslash = "IntlBackslash", intlYen = "IntlYen"
    case intlRo = "IntlRo"
    // Editing and whitespace
    case enter = "Enter", tab = "Tab", space = "Space", backspace = "Backspace", escape = "Escape"
    case delete = "Delete", insert = "Insert"
    // Navigation
    case arrowUp = "ArrowUp", arrowDown = "ArrowDown", arrowLeft = "ArrowLeft", arrowRight = "ArrowRight"
    case home = "Home", end = "End", pageUp = "PageUp", pageDown = "PageDown"
    // Function keys
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4", f5 = "F5", f6 = "F6", f7 = "F7", f8 = "F8", f9 = "F9"
    case f10 = "F10", f11 = "F11", f12 = "F12", f13 = "F13", f14 = "F14", f15 = "F15", f16 = "F16", f17 = "F17"
    case f18 = "F18", f19 = "F19", f20 = "F20"
    // Keypad
    case numpad0 = "Numpad0", numpad1 = "Numpad1", numpad2 = "Numpad2", numpad3 = "Numpad3", numpad4 = "Numpad4"
    case numpad5 = "Numpad5", numpad6 = "Numpad6", numpad7 = "Numpad7", numpad8 = "Numpad8", numpad9 = "Numpad9"
    case numpadDecimal = "NumpadDecimal", numpadMultiply = "NumpadMultiply", numpadAdd = "NumpadAdd"
    case numpadSubtract = "NumpadSubtract", numpadDivide = "NumpadDivide", numpadEnter = "NumpadEnter"
    case numpadEqual = "NumpadEqual", numpadComma = "NumpadComma", numLock = "NumLock"
    // Modifiers
    case shiftLeft = "ShiftLeft", shiftRight = "ShiftRight", controlLeft = "ControlLeft"
    case controlRight = "ControlRight", altLeft = "AltLeft", altRight = "AltRight", metaLeft = "MetaLeft"
    case metaRight = "MetaRight", capsLock = "CapsLock", fn = "Fn"
    // Other
    case contextMenu = "ContextMenu", lang1 = "Lang1", lang2 = "Lang2", audioVolumeUp = "AudioVolumeUp"
    case audioVolumeDown = "AudioVolumeDown", audioVolumeMute = "AudioVolumeMute"

    /// The key of a macOS virtual key code (`kVK_*`), nil for codes no
    /// keyboard sends. Saved bindings stored these codes before October 2026.
    public init?(macKeyCode: UInt16) {
        guard let key = Self.byMacKeyCode[macKeyCode] else { return nil }
        self = key
    }

    private static let byMacKeyCode: [UInt16: KeyboardKey] = [
        0x00: .keyA, 0x01: .keyS, 0x02: .keyD, 0x03: .keyF, 0x04: .keyH, 0x05: .keyG, 0x06: .keyZ, 0x07: .keyX,
        0x08: .keyC, 0x09: .keyV, 0x0A: .intlBackslash, 0x0B: .keyB, 0x0C: .keyQ, 0x0D: .keyW, 0x0E: .keyE,
        0x0F: .keyR, 0x10: .keyY, 0x11: .keyT, 0x12: .digit1, 0x13: .digit2, 0x14: .digit3, 0x15: .digit4,
        0x16: .digit6, 0x17: .digit5, 0x18: .equal, 0x19: .digit9, 0x1A: .digit7, 0x1B: .minus, 0x1C: .digit8,
        0x1D: .digit0, 0x1E: .bracketRight, 0x1F: .keyO, 0x20: .keyU, 0x21: .bracketLeft, 0x22: .keyI, 0x23: .keyP,
        0x24: .enter, 0x25: .keyL, 0x26: .keyJ, 0x27: .quote, 0x28: .keyK, 0x29: .semicolon, 0x2A: .backslash,
        0x2B: .comma, 0x2C: .slash, 0x2D: .keyN, 0x2E: .keyM, 0x2F: .period, 0x30: .tab, 0x31: .space,
        0x32: .backquote, 0x33: .backspace, 0x35: .escape, 0x36: .metaRight, 0x37: .metaLeft, 0x38: .shiftLeft,
        0x39: .capsLock, 0x3A: .altLeft, 0x3B: .controlLeft, 0x3C: .shiftRight, 0x3D: .altRight, 0x3E: .controlRight,
        0x3F: .fn, 0x40: .f17, 0x41: .numpadDecimal, 0x43: .numpadMultiply, 0x45: .numpadAdd, 0x47: .numLock,
        0x48: .audioVolumeUp, 0x49: .audioVolumeDown, 0x4A: .audioVolumeMute, 0x4B: .numpadDivide,
        0x4C: .numpadEnter, 0x4E: .numpadSubtract, 0x4F: .f18, 0x50: .f19, 0x51: .numpadEqual, 0x52: .numpad0,
        0x53: .numpad1, 0x54: .numpad2, 0x55: .numpad3, 0x56: .numpad4, 0x57: .numpad5, 0x58: .numpad6,
        0x59: .numpad7, 0x5A: .f20, 0x5B: .numpad8, 0x5C: .numpad9, 0x5D: .intlYen, 0x5E: .intlRo,
        0x5F: .numpadComma, 0x60: .f5, 0x61: .f6, 0x62: .f7, 0x63: .f3, 0x64: .f8, 0x65: .f9, 0x66: .lang2,
        0x67: .f11, 0x68: .lang1, 0x69: .f13, 0x6A: .f16, 0x6B: .f14, 0x6D: .f10, 0x6E: .contextMenu, 0x6F: .f12,
        0x71: .f15, 0x72: .insert, 0x73: .home, 0x74: .pageUp, 0x75: .delete, 0x76: .f4, 0x77: .end, 0x78: .f2,
        0x79: .pageDown, 0x7A: .f1, 0x7B: .arrowLeft, 0x7C: .arrowRight, 0x7D: .arrowDown, 0x7E: .arrowUp,
    ]
}
