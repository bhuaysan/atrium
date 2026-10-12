// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore
import Foundation
import simd

/// A logical RetroPad input that can be bound to a key.
nonisolated enum RetroInput: String, CaseIterable, Codable, Identifiable, Sendable {
    case up, down, left, right
    case a, b, x, y
    case l, r, l2, r2, l3, r3
    case start, select
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up: String(localized: "D-Pad Up")
        case .down: String(localized: "D-Pad Down")
        case .left: String(localized: "D-Pad Left")
        case .right: String(localized: "D-Pad Right")
        case .a: "A"
        case .b: "B"
        case .x: "X"
        case .y: "Y"
        case .l: "L"
        case .r: "R"
        case .l2: "L2"
        case .r2: "R2"
        case .l3: "L3"
        case .r3: "R3"
        case .start: "Start"
        case .select: "Select"
        case .leftStickUp: String(localized: "Left Stick Up")
        case .leftStickDown: String(localized: "Left Stick Down")
        case .leftStickLeft: String(localized: "Left Stick Left")
        case .leftStickRight: String(localized: "Left Stick Right")
        case .rightStickUp: String(localized: "Right Stick Up")
        case .rightStickDown: String(localized: "Right Stick Down")
        case .rightStickLeft: String(localized: "Right Stick Left")
        case .rightStickRight: String(localized: "Right Stick Right")
        }
    }

    var button: RetroButton? {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .a: .A
        case .b: .B
        case .x: .X
        case .y: .Y
        case .l: .L
        case .r: .R
        case .l2: .L2
        case .r2: .R2
        case .l3: .L3
        case .r3: .R3
        case .start: .start
        case .select: .select
        default: nil
        }
    }

    enum Group: String, CaseIterable, Identifiable {
        case dpad, buttons, shoulders, system, leftStick, rightStick
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dpad: String(localized: "D-Pad")
            case .buttons: String(localized: "Face Buttons")
            case .shoulders: String(localized: "Shoulder Buttons")
            case .system: String(localized: "Start & Select")
            case .leftStick: String(localized: "Left Analog Stick")
            case .rightStick: String(localized: "Right Analog Stick")
            }
        }
    }

    var group: Group {
        switch self {
        case .up, .down, .left, .right: .dpad
        case .a, .b, .x, .y: .buttons
        case .l, .r, .l2, .r2, .l3, .r3: .shoulders
        case .start, .select: .system
        case .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight: .leftStick
        case .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight: .rightStick
        }
    }
}

/// RetroPad state produced by one controller.
nonisolated struct PadState: Equatable, Sendable {
    var buttonMask: UInt32 = 0
    var leftStick: SIMD2<Float> = .zero
    var rightStick: SIMD2<Float> = .zero

    static let stickDeadZone: Float = 0.15

    mutating func set(_ button: RetroButton, _ pressed: Bool) {
        if pressed { buttonMask |= 1 << UInt32(button.rawValue) }
    }

    /// Removes stick noise around the centre and rescales the rest to 0…1.
    static func applyDeadZone(_ value: Float) -> Float {
        let magnitude = abs(value)
        guard magnitude > stickDeadZone else { return 0 }
        return copysign(min((magnitude - stickDeadZone) / (1 - stickDeadZone), 1), value)
    }
}

/// Keyboard layout for player 1. Defaults follow RetroArch conventions.
nonisolated struct KeyboardMapping: Codable, Equatable, Sendable {
    var bindings: [RetroInput: KeyBinding]

    static let standard = KeyboardMapping(bindings: [
        .up: KeyBinding(key: .arrowUp, label: "↑"),
        .down: KeyBinding(key: .arrowDown, label: "↓"),
        .left: KeyBinding(key: .arrowLeft, label: "←"),
        .right: KeyBinding(key: .arrowRight, label: "→"),
        .a: KeyBinding(key: .keyX, label: "X"),
        .b: KeyBinding(key: .keyZ, label: "Z"),
        .x: KeyBinding(key: .keyS, label: "S"),
        .y: KeyBinding(key: .keyA, label: "A"),
        .l: KeyBinding(key: .keyQ, label: "Q"),
        .r: KeyBinding(key: .keyW, label: "W"),
        .l2: KeyBinding(key: .keyE, label: "E"),
        .r2: KeyBinding(key: .keyR, label: "R"),
        .l3: KeyBinding(key: .digit1, label: "1"),
        .r3: KeyBinding(key: .digit2, label: "2"),
        .start: KeyBinding(key: .enter, label: "↩"),
        .select: KeyBinding(key: .shiftRight, label: "⇧ right"),
        .leftStickUp: KeyBinding(key: .keyI, label: "I"),
        .leftStickDown: KeyBinding(key: .keyK, label: "K"),
        .leftStickLeft: KeyBinding(key: .keyJ, label: "J"),
        .leftStickRight: KeyBinding(key: .keyL, label: "L"),
        .rightStickUp: KeyBinding(key: .keyT, label: "T"),
        .rightStickDown: KeyBinding(key: .keyG, label: "G"),
        .rightStickLeft: KeyBinding(key: .keyF, label: "F"),
        .rightStickRight: KeyBinding(key: .keyH, label: "H"),
    ])

    static var current: KeyboardMapping {
        get {
            guard let data = UserDefaults.standard.data(forKey: PrefKey.keyboardMapping),
                  let mapping = try? JSONDecoder().decode(KeyboardMapping.self, from: data) else { return .standard }
            return mapping
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: PrefKey.keyboardMapping)
        }
    }

    func input(for key: KeyboardKey) -> [RetroInput] {
        bindings.filter { $0.value.key == key }.map(\.key)
    }
}
