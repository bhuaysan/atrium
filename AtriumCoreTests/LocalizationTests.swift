// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import AtriumCore

/// AtriumCore's strings live in its own catalog (`AtriumCore/Resources`),
/// looked up with `bundle: .module`.
struct LocalizationTests {
    @Test func germanStringsShipWithThePackage() throws {
        let path = try #require(Bundle.module.path(forResource: "de", ofType: "lproj"))
        let german = try #require(Bundle(path: path))
        #expect(german.localizedString(forKey: "Ambient Light", value: nil, table: nil) == "Umgebungslicht")
        #expect(german.localizedString(forKey: "The core could not be downloaded: %@", value: nil, table: nil)
            == "Der Core konnte nicht geladen werden: %@")
    }
}
