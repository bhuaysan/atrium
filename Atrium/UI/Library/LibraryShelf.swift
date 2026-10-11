// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

nonisolated enum LibrarySelection: Hashable {
    case all, favorites, recent, hidden
    case system(String)
    case collection(String)
}

/// What the content column shows. See docs/DESIGN_SPEC.md, section H.
nonisolated enum LibraryState: Equatable {
    case welcome
    /// The first scan is running and no game is known yet.
    case scanning
    case noGames
    /// The library is the empty folder structure: games still need to be copied in.
    case awaitingGames
    case noResults(query: String)
    case noFilterResults
    case noFavorites
    case nothingPlayed
    case emptyCollection
    case games

    init(hasFolders: Bool, isScanning: Bool, libraryCount: Int, visibleCount: Int, searchText: String,
         selection: LibrarySelection, isFiltered: Bool = false, usesFolderStructure: Bool = false) {
        if !hasFolders {
            self = .welcome
        } else if visibleCount > 0 {
            self = .games
        } else if libraryCount == 0 {
            // A scan with games already known keeps the grid; progress is in the activity footer.
            self = isScanning ? .scanning : usesFolderStructure ? .awaitingGames : .noGames
        } else if !searchText.isEmpty {
            self = .noResults(query: searchText)
        } else if isFiltered {
            self = .noFilterResults
        } else {
            switch selection {
            case .favorites: self = .noFavorites
            case .recent: self = .nothingPlayed
            case .collection: self = .emptyCollection
            // A system without games has no sidebar row; LibraryView falls back to All Games.
            case .all, .system, .hidden: self = .games
            }
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case title, recentlyAdded, recentlyPlayed, releaseYear, system, playTime
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .title: "Title"
        case .recentlyAdded: "Recently Added"
        case .recentlyPlayed: "Recently Played"
        case .releaseYear: "Release Year"
        case .system: "System"
        case .playTime: "Play Time"
        }
    }

    /// Dates and play time list the latest and longest first.
    var isDescendingByDefault: Bool {
        self == .recentlyAdded || self == .recentlyPlayed || self == .playTime
    }

    /// `games` in this order; `games` comes sorted by title, which breaks ties.
    func sorted(_ games: [Game]) -> [Game] {
        switch self {
        case .title: games
        case .recentlyAdded: games.sorted { $0.dateAdded > $1.dateAdded }
        case .recentlyPlayed: games.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .releaseYear: games.sorted { ($0.releaseDate ?? "9999") < ($1.releaseDate ?? "9999") }
        case .system: games.sorted { ($0.system?.name ?? $0.systemID) < ($1.system?.name ?? $1.systemID) }
        case .playTime: games.sorted { $0.playTime > $1.playTime }
        }
    }
}

/// The games in view and what the views around them need to know: the
/// library with the sidebar selection, search, filter and sort applied.
struct LibraryShelf {
    /// What the user chose to see.
    struct Query {
        var selection: LibrarySelection = .all
        var searchText = ""
        var filter = LibraryFilter()
        var sort = LibrarySort.title
        var isSortReversed = false
        var groupsVariants = true
    }

    /// Sidebar selection, search, filter and sort applied; one game per
    /// group when versions are grouped.
    let games: [Game]
    let groups: VariantGroups
    let filterOptions: LibraryFilterOptions
    let isGrouped: Bool

    /// `library` is every game, hidden ones included, sorted by title.
    init(library: [Game], query: Query) {
        let visible = library.filter { !$0.isHidden }
        let scope = Self.scope(of: library, for: query.selection)
        groups = VariantGroups(query.selection == .hidden ? library.filter(\.isHidden) : visible)
        var result = scope
        if !query.searchText.isEmpty {
            result = result.filter { Self.matches($0, search: query.searchText) }
        }
        if query.filter.isActive { result = result.filter(query.filter.matches) }
        if query.selection == .recent {
            result = LibrarySort.recentlyPlayed.sorted(result)
        } else {
            result = query.sort.sorted(result)
            if query.isSortReversed { result.reverse() }
        }
        // Hidden lists every hidden file; elsewhere one card stands for all versions.
        isGrouped = query.groupsVariants && query.selection != .hidden
        if isGrouped { result = groups.collapse(result) }
        games = result
        filterOptions = LibraryFilter.options(for: scope)
    }

    /// The games of the sidebar selection, before search and filters.
    static func scope(of library: [Game], for selection: LibrarySelection) -> [Game] {
        let games = library.filter { !$0.isHidden }
        return switch selection {
        case .all: games
        case .favorites: games.filter(\.isFavorite)
        case .recent: games.filter { $0.lastPlayed != nil }
        case .hidden: library.filter(\.isHidden)
        case .system(let id): games.filter { $0.systemID == id }
        case .collection(let name): games.filter { $0.collections.contains(name) }
        }
    }

    /// Search looks at the title, developer, genre and collections.
    static func matches(_ game: Game, search: String) -> Bool {
        game.title.localizedStandardContains(search)
            || (game.developer?.localizedStandardContains(search) ?? false)
            || (game.genre?.localizedStandardContains(search) ?? false)
            || game.collections.contains { $0.localizedStandardContains(search) }
    }
}
