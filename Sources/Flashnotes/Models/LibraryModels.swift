import Foundation
import SwiftData

enum LibraryItemKind: String, Codable, CaseIterable {
    case deck
    case note
}

enum LibrarySortMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case title
    case created
    case modified

    var id: String { rawValue }
    var title: String {
        switch self {
        case .manual: "Manual"
        case .title: "Name"
        case .created: "Date Created"
        case .modified: "Date Modified"
        }
    }
}

@Model
final class LibraryFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int
    var createdAt: Date
    // Optional additions keep existing SwiftData stores eligible for lightweight migration.
    var modifiedAt: Date?
    var favoriteAt: Date?
    var lastOpenedAt: Date?
    var trashedAt: Date?
    var colorHex: String?
    var symbolName: String?
    var sortModeRaw: String?
    var sortAscendingValue: Bool?
    @Relationship(deleteRule: .cascade, inverse: \LibraryItem.folder) var items: [LibraryItem]
    var parent: LibraryFolder?
    @Relationship(deleteRule: .cascade, inverse: \LibraryFolder.parent) var children: [LibraryFolder]

    init(id: UUID = UUID(), name: String, sortIndex: Int, parent: LibraryFolder? = nil) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.modifiedAt = nil
        self.favoriteAt = nil
        self.lastOpenedAt = nil
        self.trashedAt = nil
        self.colorHex = nil
        self.symbolName = nil
        self.sortModeRaw = nil
        self.sortAscendingValue = nil
        self.items = []
        self.parent = parent
        self.children = []
    }

    var sortMode: LibrarySortMode {
        get { LibrarySortMode(rawValue: sortModeRaw ?? "") ?? .manual }
        set { sortModeRaw = newValue.rawValue }
    }

    var sortAscending: Bool {
        get { sortAscendingValue ?? true }
        set { sortAscendingValue = newValue }
    }

    var effectiveSymbolName: String { symbolName ?? "folder.fill" }
}

@Model
final class LibraryItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRawValue: String
    var sortIndex: Int
    var noteMarkdown: String
    var createdAt: Date
    var modifiedAt: Date
    var favoriteAt: Date?
    var lastOpenedAt: Date?
    var trashedAt: Date?
    var tagsRaw: String?
    var linkedDeckID: UUID?
    var generatedCardSignaturesRaw: String?
    var folder: LibraryFolder?
    @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck) var cards: [Flashcard]

    var kind: LibraryItemKind {
        get { LibraryItemKind(rawValue: kindRawValue) ?? .note }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        kind: LibraryItemKind,
        sortIndex: Int,
        folder: LibraryFolder? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRawValue = kind.rawValue
        self.sortIndex = sortIndex
        self.noteMarkdown = ""
        self.createdAt = .now
        self.modifiedAt = .now
        self.favoriteAt = nil
        self.lastOpenedAt = nil
        self.trashedAt = nil
        self.tagsRaw = nil
        self.linkedDeckID = nil
        self.generatedCardSignaturesRaw = nil
        self.folder = folder
        self.cards = []
    }


    var tags: [String] {
        get {
            (tagsRaw ?? "")
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = Array(Set(newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        }
    }

    var generatedCardSignatures: Set<String> {
        get { Set((generatedCardSignaturesRaw ?? "").split(separator: "\n").map(String.init)) }
        set { generatedCardSignaturesRaw = newValue.sorted().joined(separator: "\n") }
    }
}

@Model
final class Flashcard {
    @Attribute(.unique) var id: UUID
    var front: String
    var back: String
    var sortIndex: Int
    var deck: LibraryItem?

    init(
        id: UUID = UUID(),
        front: String = "",
        back: String = "",
        sortIndex: Int,
        deck: LibraryItem? = nil
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.sortIndex = sortIndex
        self.deck = deck
    }
}
