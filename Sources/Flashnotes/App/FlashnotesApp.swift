import AppKit
import SwiftData
import SwiftUI

@main
struct FlashnotesApp: App {
    @State private var preferences = Preferences()
    @State private var session = SessionStore()
    private let container: ModelContainer

    init() {
        if let iconURL = Bundle.main.url(forResource: "FlashnotesIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        let schema = Schema([LibraryFolder.self, LibraryItem.self, Flashcard.self])
        let testing = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = try! PersistenceStore.configuration(schema: schema, inMemory: testing)
        container = try! ModelContainer(for: schema, configurations: [configuration])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .environment(session)
                .preferredColorScheme(preferences.appearance.colorScheme)
                .frame(minWidth: 640, minHeight: 480)
        }
        .modelContainer(container)
        .commands { FlashnotesCommands(preferences: preferences) }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified(showsTitle: true))

        Settings {
            SettingsView()
                .environment(preferences)
                .preferredColorScheme(preferences.appearance.colorScheme)
        }
    }
}

extension Notification.Name {
    static let newFolder = Notification.Name("Flashnotes.newFolder")
    static let newDeck = Notification.Name("Flashnotes.newDeck")
    static let newNote = Notification.Name("Flashnotes.newNote")
    static let newCard = Notification.Name("Flashnotes.newCard")
    static let startReview = Notification.Name("Flashnotes.startReview")
    static let closeTab = Notification.Name("Flashnotes.closeTab")
    static let markdownBold = Notification.Name("Flashnotes.markdownBold")
    static let markdownItalic = Notification.Name("Flashnotes.markdownItalic")
    static let markdownHighlight = Notification.Name("Flashnotes.markdownHighlight")
    static let markdownCode = Notification.Name("Flashnotes.markdownCode")
    static let markdownLink = Notification.Name("Flashnotes.markdownLink")
    static let showLibrarySearch = Notification.Name("Flashnotes.showLibrarySearch")
    static let showCommandPalette = Notification.Name("Flashnotes.showCommandPalette")
    static let navigateBack = Notification.Name("Flashnotes.navigateBack")
    static let navigateForward = Notification.Name("Flashnotes.navigateForward")
    static let navigateHome = Notification.Name("Flashnotes.navigateHome")
    static let toggleSidebar = Notification.Name("Flashnotes.toggleSidebar")
    static let openTrash = Notification.Name("Flashnotes.openTrash")
    static let moveSelectionToTrash = Notification.Name("Flashnotes.moveSelectionToTrash")
    static let toggleFavorite = Notification.Name("Flashnotes.toggleFavorite")
    static let editTags = Notification.Name("Flashnotes.editTags")
    static let editFolderAppearance = Notification.Name("Flashnotes.editFolderAppearance")
    static let expandAllFolders = Notification.Name("Flashnotes.expandAllFolders")
    static let collapseAllFolders = Notification.Name("Flashnotes.collapseAllFolders")
    static let cycleFolderSort = Notification.Name("Flashnotes.cycleFolderSort")
    static let reverseFolderSort = Notification.Name("Flashnotes.reverseFolderSort")
    static let chooseLinkedDeck = Notification.Name("Flashnotes.chooseLinkedDeck")
    static let exportMarkdown = Notification.Name("Flashnotes.exportMarkdown")
    static let exportPlainText = Notification.Name("Flashnotes.exportPlainText")
    static let exportPDF = Notification.Name("Flashnotes.exportPDF")
}

struct FlashnotesCommands: Commands {
    let preferences: Preferences

    var body: some Commands {
        CommandGroup(after: .newItem) {
            commandButton("New Folder", notification: .newFolder, action: .newFolder)
            commandButton("New Deck", notification: .newDeck, action: .newDeck)
            commandButton("New Note", notification: .newNote, action: .newNote)
        }
        CommandMenu("Review") {
            commandButton("Start Review", notification: .startReview, action: .startReview)
        }
        CommandMenu("Navigate") {
            commandButton("Back", notification: .navigateBack, action: .back)
            commandButton("Forward", notification: .navigateForward, action: .forward)
            commandButton("Home", notification: .navigateHome, action: .home)
            commandButton("Show or Hide Sidebar", notification: .toggleSidebar, action: .toggleSidebar)
            Divider()
            commandButton("Search Library", notification: .showLibrarySearch, action: .search)
            commandButton("Command Palette", notification: .showCommandPalette, action: .commandPalette)
        }
        CommandMenu("Library") {
            commandButton("Open Trash", notification: .openTrash, action: .openTrash)
            commandButton("Move Selection to Trash", notification: .moveSelectionToTrash, action: .moveToTrash)
            Divider()
            commandButton("Add or Remove Favorite", notification: .toggleFavorite, action: .toggleFavorite)
            commandButton("Edit Tags", notification: .editTags, action: .editTags)
            commandButton("Folder Appearance", notification: .editFolderAppearance, action: .folderAppearance)
            Divider()
            commandButton("Expand All Folders", notification: .expandAllFolders, action: .expandAll)
            commandButton("Collapse All Folders", notification: .collapseAllFolders, action: .collapseAll)
            commandButton("Cycle Folder Sort", notification: .cycleFolderSort, action: .cycleSort)
            commandButton("Reverse Sort Direction", notification: .reverseFolderSort, action: .reverseSort)
        }
        CommandMenu("Note") {
            commandButton("Choose Card Deck", notification: .chooseLinkedDeck, action: .chooseLinkedDeck)
            Divider()
            commandButton("Export as Markdown", notification: .exportMarkdown, action: .exportMarkdown)
            commandButton("Export as Plain Text", notification: .exportPlainText, action: .exportPlainText)
            commandButton("Export as PDF", notification: .exportPDF, action: .exportPDF)
        }
        CommandMenu("Markdown") {
            commandButton("Bold", notification: .markdownBold, action: .bold)
            commandButton("Italic", notification: .markdownItalic, action: .italic)
            commandButton("Highlight", notification: .markdownHighlight, action: .highlight)
            commandButton("Inline Code", notification: .markdownCode, action: .inlineCode)
            commandButton("Link", notification: .markdownLink, action: .link)
        }
        CommandGroup(after: .saveItem) {
            commandButton("Close Tab", notification: .closeTab, action: .closeTab)
        }
    }

    @ViewBuilder
    private func commandButton(_ title: String, notification: Notification.Name, action: ShortcutAction) -> some View {
        if let key = preferences.shortcut(for: action).key {
            Button(title) { NotificationCenter.default.post(name: notification, object: nil) }
                .keyboardShortcut(key, modifiers: preferences.shortcut(for: action).modifiers)
        } else {
            Button(title) { NotificationCenter.default.post(name: notification, object: nil) }
        }
    }
}
