// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import AtriumCore

struct KeyboardKeyTests {
    @Test func everyKeyHasOneMacKeyCode() {
        let keys = (UInt16(0)..<128).compactMap { KeyboardKey(macKeyCode: $0) }
        #expect(Set(keys).count == keys.count, "Two key codes name the same key")
        #expect(Set(keys) == Set(KeyboardKey.allCases))
        #expect(KeyboardKey(macKeyCode: 0x06) == .keyZ && KeyboardKey(macKeyCode: 0x3C) == .shiftRight)
        #expect(KeyboardKey(macKeyCode: 0x34) == nil)
    }

    @Test func bindingsSaveTheKeysName() throws {
        let data = try JSONEncoder().encode(KeyBinding(key: .arrowUp, label: "↑"))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["key": "ArrowUp", "label": "↑"])
        #expect(try JSONDecoder().decode(KeyBinding.self, from: data) == KeyBinding(key: .arrowUp, label: "↑"))
    }

    @Test func bindingsSavedWithMacKeyCodesStillRead() throws {
        let old = Data(#"[{"keyCode": 126, "label": "↑"}, {"keyCode": 60, "label": "⇧ right"}]"#.utf8)
        let bindings = try JSONDecoder().decode([KeyBinding].self, from: old)
        #expect(bindings == [KeyBinding(key: .arrowUp, label: "↑"), KeyBinding(key: .shiftRight, label: "⇧ right")])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(KeyBinding.self, from: Data(#"{"keyCode": 52, "label": "?"}"#.utf8))
        }
    }

    @Test func keysTypeByPosition() {
        #expect(EmulatedKeyboard.retroKey(for: .keyZ) == 122)
        #expect(EmulatedKeyboard.retroKey(for: .numLock) == 12)  // the Mac's Clear key: RETROK_CLEAR
        #expect(EmulatedKeyboard.retroKey(for: .fn) == nil)
    }
}
