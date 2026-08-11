import Foundation
import SwiftData
import XCTest
@testable import Flashnotes

final class ReviewSessionTests: XCTestCase {
    func testOrderedReviewPreservesSequence() {
        let ids = [UUID(), UUID(), UUID()]
        var session = ReviewSession(cardIDs: ids, order: .ordered)
        XCTAssertEqual(session.cardIDs, ids)
        XCTAssertEqual(session.currentCardID, ids[0])
        session.space()
        session.space()
        XCTAssertEqual(session.currentCardID, ids[1])
    }

    func testRandomReviewContainsEveryCardExactlyOnce() {
        let ids = (0..<30).map { _ in UUID() }
        let session = ReviewSession(cardIDs: ids, order: .random, shuffle: { Array($0.reversed()) })
        XCTAssertEqual(session.cardIDs.count, ids.count)
        XCTAssertEqual(Set(session.cardIDs), Set(ids))
        XCTAssertEqual(session.cardIDs, Array(ids.reversed()))
    }

    func testSpaceKeyStateTransitionsThroughCompletion() {
        let ids = [UUID(), UUID()]
        var session = ReviewSession(cardIDs: ids, order: .ordered)
        XCTAssertEqual(session.face, .front)
        session.space()
        XCTAssertEqual(session.face, .back)
        XCTAssertEqual(session.currentCardID, ids[0])
        session.space()
        XCTAssertEqual(session.face, .front)
        XCTAssertEqual(session.currentCardID, ids[1])
        session.space()
        XCTAssertEqual(session.face, .back)
        session.space()
        XCTAssertEqual(session.face, .complete)
        XCTAssertNil(session.currentCardID)
    }
}

final class HeadingParserTests: XCTestCase {
    func testHeadingHierarchyAndRanges() {
        let markdown = "# Course\n## Week One\n### Topic A\n## Week Two\n# Appendix"
        let headings = HeadingParser.hierarchy(in: markdown)
        XCTAssertEqual(headings.map(\.title), ["Course", "Appendix"])
        XCTAssertEqual(headings[0].children.map(\.title), ["Week One", "Week Two"])
        XCTAssertEqual(headings[0].children[0].children.map(\.title), ["Topic A"])
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[0].range.location, 0)
    }

    func testNonHeadingsAreIgnored() {
        XCTAssertTrue(HeadingParser.hierarchy(in: "A # symbol\n#Missing space\nNormal").isEmpty)
    }
}

final class MathRendererTests: XCTestCase {
    func testCommonLatexCommandsRenderOffline() {
        XCTAssertEqual(MathRenderer.displayString(for: #"E=mc^2"#), "E=mc²")
        XCTAssertEqual(MathRenderer.displayString(for: #"\alpha + \beta \neq \infty"#), "α + β ≠ ∞")
        XCTAssertEqual(MathRenderer.displayString(for: #"\frac{1}{2} + \sqrt{x}"#), "1⁄2 + √(x)")
        XCTAssertEqual(MathRenderer.displayString(for: #"x_{10}"#), "x₁₀")
    }
}

final class AttachmentStoreTests: XCTestCase {
    func testStableAttachmentReferenceCreationAndParsing() {
        let reference = AttachmentStore.reference(for: "a1b2c3.jpg")
        XCTAssertEqual(reference, "attachment://a1b2c3.jpg")
        XCTAssertEqual(AttachmentStore.filename(from: reference), "a1b2c3.jpg")
        XCTAssertEqual(AttachmentStore.filenames(in: "![Photo](\(reference))"), ["a1b2c3.jpg"])
        XCTAssertEqual(AttachmentStore.filenames(in: "![Photo](\(reference)){width=360}"), ["a1b2c3.jpg"])
        XCTAssertNil(AttachmentStore.filename(from: "attachment://../secret"))
    }
}

final class LibraryFeatureTests: XCTestCase {
    func testAutoCardParserUsesFirstDoubleColonAndIgnoresIncompleteLines() {
        let values = AutoCardParser.candidates(in: "Capital of France :: Paris\nIncomplete ::\nRatio :: 1::2")
        XCTAssertEqual(values, [
            AutoCardCandidate(front: "Capital of France", back: "Paris"),
            AutoCardCandidate(front: "Ratio", back: "1::2")
        ])
        XCTAssertEqual(Set(values.map(\.signature)).count, 2)
    }

    func testNoteStatisticsAndPlainText() {
        let markdown = "# Heading\nThis is **four** useful words."
        let statistics = LibraryFeatures.noteStatistics(markdown)
        XCTAssertEqual(statistics.words, 6)
        XCTAssertEqual(statistics.characters, markdown.count)
        XCTAssertEqual(statistics.readingMinutes, 1)
        XCTAssertFalse(LibraryFeatures.plainText(from: markdown).contains("**"))
    }
}

@MainActor
final class ShortcutAndRecentTests: XCTestCase {
    func testShortcutChoicesSupportDisablingAndModifierRendering() {
        XCTAssertNil(AppShortcut.none.key)
        XCTAssertEqual(AppShortcut(rawValue: "commandOptionP").title, "⌘⌥P")
        XCTAssertEqual(ShortcutAction.expandAll.defaultShortcut.title, "⌘⌥↓")
    }

    func testOpeningAnItemRecordsItInPersistentRecents() {
        let suite = "FlashnotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let folder = LibraryFolder(name: "Folder", sortIndex: 0)
        let note = LibraryItem(title: "Recent Note", kind: .note, sortIndex: 0, folder: folder)
        let session = SessionStore(defaults: defaults)
        session.open(note)

        XCTAssertEqual(session.recentItemIDs, [note.id])
        XCTAssertEqual(SessionStore(defaults: defaults).recentItemIDs, [note.id])
    }
}

final class SessionQuoteLibraryTests: XCTestCase {
    func testQuotePoolContainsAtLeastThreeHundredUniqueQuotes() {
        XCTAssertGreaterThanOrEqual(SessionQuoteLibrary.all.count, 300)
        XCTAssertEqual(Set(SessionQuoteLibrary.all.map(\.text)).count, SessionQuoteLibrary.all.count)
        XCTAssertTrue(SessionQuoteLibrary.all.allSatisfy { !$0.author.isEmpty })
        XCTAssertGreaterThanOrEqual(Set(SessionQuoteLibrary.all.map(\.author)).count, 40)
        XCTAssertFalse(SessionQuoteLibrary.all.contains { $0.author == "Flashnotes" })
    }

    func testGreetingPoolCoversAtLeastThirtyLanguages() {
        XCTAssertGreaterThanOrEqual(SessionGreetingLibrary.all.count, 30)
        XCTAssertEqual(Set(SessionGreetingLibrary.all).count, SessionGreetingLibrary.all.count)
        XCTAssertTrue(SessionGreetingLibrary.all.allSatisfy { !$0.isEmpty })
    }
}

final class PersistenceStoreTests: XCTestCase {
    func testLegacyStoreFamilyMigratesToStableFlashnotesDirectory() throws {
        let fileManager = FileManager.default
        let support = fileManager.temporaryDirectory.appending(path: "FlashnotesMigration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: support) }

        let legacy = support.appending(path: "default.store")
        try Data("database".utf8).write(to: legacy)
        try Data("pending".utf8).write(to: URL(fileURLWithPath: legacy.path + "-wal"))

        let destination = try PersistenceStore.prepareStore(in: support, fileManager: fileManager)
        XCTAssertEqual(destination.lastPathComponent, "Flashnotes.store")
        XCTAssertEqual(try Data(contentsOf: destination), Data("database".utf8))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: destination.path + "-wal")), Data("pending".utf8))
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    func testFoldersItemsCardsAndOrderingPersist() throws {
        let schema = Schema([LibraryFolder.self, LibraryItem.self, Flashcard.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let second = LibraryFolder(name: "Second", sortIndex: 1)
        let first = LibraryFolder(name: "First", sortIndex: 0)
        let nested = LibraryFolder(name: "Nested", sortIndex: 0, parent: first)
        first.colorHex = "#0A84FF"
        first.symbolName = "book.closed.fill"
        first.favoriteAt = .now
        context.insert(second)
        context.insert(first)
        context.insert(nested)
        first.children.append(nested)
        let deck = LibraryItem(title: "Biology", kind: .deck, sortIndex: 0, folder: first)
        deck.tags = ["science", "exam"]
        context.insert(deck)
        first.items.append(deck)
        let laterCard = Flashcard(front: "B", back: "2", sortIndex: 1, deck: deck)
        let earlierCard = Flashcard(front: "A", back: "1", sortIndex: 0, deck: deck)
        context.insert(laterCard)
        context.insert(earlierCard)
        deck.cards.append(contentsOf: [laterCard, earlierCard])
        try context.save()

        var folderDescriptor = FetchDescriptor<LibraryFolder>(sortBy: [SortDescriptor(\.sortIndex)])
        folderDescriptor.fetchLimit = 10
        let fetchedFolders = try context.fetch(folderDescriptor)
        XCTAssertEqual(Set(fetchedFolders.map(\.name)), Set(["First", "Nested", "Second"]))
        XCTAssertEqual(fetchedFolders.filter { $0.parent == nil }.map(\.name), ["First", "Second"])
        XCTAssertEqual(fetchedFolders.first { $0.name == "First" }?.items.first?.title, "Biology")
        XCTAssertEqual(fetchedFolders.first { $0.name == "First" }?.items.first?.cards.sorted { $0.sortIndex < $1.sortIndex }.map(\.front), ["A", "B"])
        XCTAssertEqual(fetchedFolders.first { $0.name == "First" }?.children.first?.name, "Nested")
        XCTAssertEqual(fetchedFolders.first { $0.name == "Nested" }?.parent?.name, "First")
        XCTAssertEqual(fetchedFolders.first { $0.name == "First" }?.colorHex, "#0A84FF")
        XCTAssertEqual(fetchedFolders.first { $0.name == "First" }?.symbolName, "book.closed.fill")
        XCTAssertEqual(Set(fetchedFolders.first { $0.name == "First" }?.items.first?.tags ?? []), Set(["science", "exam"]))
    }
}
