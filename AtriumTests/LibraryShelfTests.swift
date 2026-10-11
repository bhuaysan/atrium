// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Atrium

private func game(_ title: String, system: String = "snes") -> Game {
    Game(path: "/ROMs/\(title).sfc", systemID: system, title: title, fileName: "\(title).sfc", fileSize: 3, crc32: nil)
}

@Suite("Library shelf")
struct LibraryShelfTests {
    private func titles(_ library: [Game], _ query: LibraryShelf.Query) -> [String] {
        LibraryShelf(library: library, query: query).games.map(\.title)
    }

    @Test func scopeFollowsTheSidebarSelection() {
        let alpha = game("Alpha")
        let beta = game("Beta", system: "gba")
        let gamma = game("Gamma")
        alpha.isFavorite = true
        beta.lastPlayed = .now
        gamma.isHidden = true
        gamma.collections = ["Couch"]
        let library = [alpha, beta, gamma]
        #expect(LibraryShelf.scope(of: library, for: .all).map(\.title) == ["Alpha", "Beta"])
        #expect(LibraryShelf.scope(of: library, for: .favorites).map(\.title) == ["Alpha"])
        #expect(LibraryShelf.scope(of: library, for: .recent).map(\.title) == ["Beta"])
        #expect(LibraryShelf.scope(of: library, for: .hidden).map(\.title) == ["Gamma"])
        #expect(LibraryShelf.scope(of: library, for: .system("snes")).map(\.title) == ["Alpha"])
        // Hidden games stay out of collections.
        #expect(LibraryShelf.scope(of: library, for: .collection("Couch")).isEmpty)
    }

    @Test func searchLooksAtTitleDeveloperGenreAndCollections() {
        let alpha = game("Alpha")
        alpha.developer = "Nintendo"
        let beta = game("Beta")
        beta.genre = "Platformer"
        let gamma = game("Gamma")
        gamma.collections = ["Couch Co-op"]
        let library = [alpha, beta, gamma]
        for (search, expected) in [("nintendo", ["Alpha"]), ("platform", ["Beta"]), ("couch", ["Gamma"]), ("gam", ["Gamma"])] {
            #expect(titles(library, .init(searchText: search, groupsVariants: false)) == expected)
        }
    }

    @Test func sortsAndReverses() {
        let alpha = game("Alpha")
        let beta = game("Beta")
        alpha.playTime = 10
        beta.playTime = 20
        let library = [alpha, beta]
        #expect(titles(library, .init(sort: .playTime, groupsVariants: false)) == ["Beta", "Alpha"])
        #expect(titles(library, .init(sort: .playTime, isSortReversed: true, groupsVariants: false)) == ["Alpha", "Beta"])
        #expect(titles(library, .init(groupsVariants: false)) == ["Alpha", "Beta"])
    }

    @Test func recentlyPlayedIgnoresTheChosenSort() {
        let alpha = game("Alpha")
        let beta = game("Beta")
        alpha.lastPlayed = .now.addingTimeInterval(-60)
        beta.lastPlayed = .now
        let shelf = LibraryShelf(library: [alpha, beta],
                                 query: .init(selection: .recent, sort: .title, isSortReversed: true))
        #expect(shelf.games.map(\.title) == ["Beta", "Alpha"])
    }

    @Test func hiddenIsNeverGrouped() {
        let shelf = LibraryShelf(library: [game("Alpha")], query: .init(selection: .hidden, groupsVariants: true))
        #expect(!shelf.isGrouped)
        #expect(LibraryShelf(library: [game("Alpha")], query: .init()).isGrouped)
    }
}
