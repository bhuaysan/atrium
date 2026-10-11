// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension Binding {
    /// Whether the optional value is set, for alerts and dialogs that
    /// present it; dismissing them clears the value.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}
