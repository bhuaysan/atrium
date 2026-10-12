// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AtriumCore

extension NSEvent {
    /// The key of a key or flagsChanged event, nil for keys Atrium does not know.
    var keyboardKey: KeyboardKey? { KeyboardKey(macKeyCode: keyCode) }
}

nonisolated extension EmulatedKeyboard {
    /// RETROKMOD_* flags for the modifier keys held.
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> UInt16 {
        var result: UInt16 = 0
        if flags.contains(.shift) { result |= 0x01 }
        if flags.contains(.control) { result |= 0x02 }
        if flags.contains(.option) { result |= 0x04 }
        if flags.contains(.command) { result |= 0x08 }
        if flags.contains(.capsLock) { result |= 0x20 }
        return result
    }

    /// The UTF-32 character a key event types, 0 for none (arrows, F keys).
    static func character(of event: NSEvent) -> UInt32 {
        guard let scalar = event.characters?.unicodeScalars.first,
              !(0xF700...0xF8FF).contains(scalar.value) else { return 0 } // AppKit's function key range
        return scalar.value
    }

    /// Whether a modifier key is down after a flagsChanged event for it.
    static func isModifierDown(_ key: KeyboardKey?, flags: NSEvent.ModifierFlags) -> Bool {
        switch key {
        case .shiftLeft, .shiftRight: flags.contains(.shift)
        case .controlLeft, .controlRight: flags.contains(.control)
        case .altLeft, .altRight: flags.contains(.option)
        case .metaLeft, .metaRight: flags.contains(.command)
        case .capsLock: flags.contains(.capsLock)
        default: false
        }
    }
}
