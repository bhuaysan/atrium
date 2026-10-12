// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import Atrium
@testable import AtriumCore

/// The files of a save state as ARMSX2 writes it: its version, every part
/// ARMSX2 requires except `omitting` (a few bytes each, not a real state)
/// and `extra` files.
func armsx2StateFiles(version: UInt32, omitting: Set<String> = [],
                      extra: [(name: String, bytes: Data)] = []) -> [(name: String, bytes: Data)] {
    var bytes = withUnsafeBytes(of: version.littleEndian) { Data($0) }
    bytes.append(contentsOf: Array("0.1 test".utf8) + [0])
    return [("PCSX2 Savestate Version.id", bytes)]
        + ARMSX2States.requiredEntries.filter { !omitting.contains($0) }.map { ($0, Data("part".utf8)) }
        + extra
}
