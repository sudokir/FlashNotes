import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var appKitAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

struct AppShortcut: RawRepresentable, Hashable, Identifiable, CaseIterable {
    let rawValue: String
    var id: String { rawValue }

    static let none = Self(rawValue: "none")
    static let commandB = Self(rawValue: "commandB")
    static let commandI = Self(rawValue: "commandI")
    static let commandE = Self(rawValue: "commandE")
    static let commandK = Self(rawValue: "commandK")
    static let commandShiftH = Self(rawValue: "commandShiftH")

    static let allCases: [Self] = {
        let letters = (65...90).compactMap(UnicodeScalar.init).map { String(Character($0)) }
        var values = [none]
        values += letters.map { Self(rawValue: "command\($0)") }
        values += letters.map { Self(rawValue: "commandShift\($0)") }
        values += letters.map { Self(rawValue: "commandOption\($0)") }
        values += letters.map { Self(rawValue: "commandControl\($0)") }
        values += [
            Self(rawValue: "commandLeftBracket"), Self(rawValue: "commandRightBracket"),
            Self(rawValue: "commandOptionUp"), Self(rawValue: "commandOptionDown"),
            Self(rawValue: "commandShiftDelete")
        ]
        return values
    }()

    var key: KeyEquivalent? {
        guard self != .none else { return nil }
        if rawValue.hasSuffix("LeftBracket") { return "[" }
        if rawValue.hasSuffix("RightBracket") { return "]" }
        if rawValue.hasSuffix("Up") { return .upArrow }
        if rawValue.hasSuffix("Down") { return .downArrow }
        if rawValue.hasSuffix("Delete") { return .delete }
        guard let character = rawValue.last else { return nil }
        return KeyEquivalent(Character(String(character).lowercased()))
    }

    var modifiers: EventModifiers {
        var value: EventModifiers = [.command]
        if rawValue.contains("Shift") { value.insert(.shift) }
        if rawValue.contains("Option") { value.insert(.option) }
        if rawValue.contains("Control") { value.insert(.control) }
        return value
    }

    var title: String {
        guard self != .none else { return "None" }
        var value = "⌘"
        if modifiers.contains(.control) { value += "⌃" }
        if modifiers.contains(.option) { value += "⌥" }
        if modifiers.contains(.shift) { value += "⇧" }
        if rawValue.hasSuffix("LeftBracket") { return value + "[" }
        if rawValue.hasSuffix("RightBracket") { return value + "]" }
        if rawValue.hasSuffix("Up") { return value + "↑" }
        if rawValue.hasSuffix("Down") { return value + "↓" }
        if rawValue.hasSuffix("Delete") { return value + "⌫" }
        return value + String(rawValue.last ?? "?").uppercased()
    }
}

typealias MarkdownShortcut = AppShortcut

enum ShortcutAction: String, CaseIterable, Identifiable {
    case newFolder, newDeck, newNote, closeTab, startReview
    case back, forward, home, toggleSidebar, search, commandPalette
    case openTrash, moveToTrash, toggleFavorite, editTags, folderAppearance
    case expandAll, collapseAll, cycleSort, reverseSort
    case chooseLinkedDeck, exportMarkdown, exportPlainText, exportPDF
    case bold, italic, highlight, inlineCode, link

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newFolder: "New Folder"
        case .newDeck: "New Deck"
        case .newNote: "New Note / Card"
        case .closeTab: "Close Tab"
        case .startReview: "Start Review"
        case .back: "Back"
        case .forward: "Forward"
        case .home: "Home"
        case .toggleSidebar: "Show or Hide Sidebar"
        case .search: "Search Library"
        case .commandPalette: "Command Palette"
        case .openTrash: "Open Trash"
        case .moveToTrash: "Move Selection to Trash"
        case .toggleFavorite: "Add or Remove Favorite"
        case .editTags: "Edit Tags"
        case .folderAppearance: "Folder Appearance"
        case .expandAll: "Expand All Folders"
        case .collapseAll: "Collapse All Folders"
        case .cycleSort: "Cycle Folder Sort"
        case .reverseSort: "Reverse Sort Direction"
        case .chooseLinkedDeck: "Choose Note's Card Deck"
        case .exportMarkdown: "Export as Markdown"
        case .exportPlainText: "Export as Plain Text"
        case .exportPDF: "Export as PDF"
        case .bold: "Bold"
        case .italic: "Italic"
        case .highlight: "Highlight"
        case .inlineCode: "Inline Code"
        case .link: "Link"
        }
    }

    var defaultShortcut: AppShortcut {
        let value: String = switch self {
        case .newFolder: "commandShiftN"
        case .newDeck: "commandD"
        case .newNote: "commandN"
        case .closeTab: "commandW"
        case .startReview: "commandShiftR"
        case .back: "commandLeftBracket"
        case .forward: "commandRightBracket"
        case .home: "commandShiftG"
        case .toggleSidebar: "commandControlS"
        case .search: "commandShiftF"
        case .commandPalette: "commandShiftP"
        case .openTrash: "commandShiftT"
        case .moveToTrash: "commandShiftDelete"
        case .toggleFavorite: "commandOptionF"
        case .editTags: "commandOptionT"
        case .folderAppearance: "commandOptionI"
        case .expandAll: "commandOptionDown"
        case .collapseAll: "commandOptionUp"
        case .cycleSort: "commandOptionS"
        case .reverseSort: "commandOptionR"
        case .chooseLinkedDeck: "commandOptionL"
        case .exportMarkdown: "commandOptionM"
        case .exportPlainText: "commandOptionX"
        case .exportPDF: "commandOptionP"
        case .bold: "commandB"
        case .italic: "commandI"
        case .highlight: "commandShiftH"
        case .inlineCode: "commandE"
        case .link: "commandK"
        }
        return AppShortcut(rawValue: value)
    }
}

@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults
    private static let appearanceKey = "appearance"
    private static let outlineKey = "outlineVisible"
    private static let highlightKey = "highlightHex"
    private static let boldShortcutKey = "boldShortcut"
    private static let italicShortcutKey = "italicShortcut"
    private static let highlightShortcutKey = "highlightShortcut"
    private static let codeShortcutKey = "codeShortcut"
    private static let linkShortcutKey = "linkShortcut"
    private static let textColorPresetsKey = "textColorPresets"
    private static let headingColorsKey = "headingColors"
    private static let appShortcutsKey = "appShortcuts.v1"

    static let defaultTextColorPresets = ["#0A84FF", "#BF5AF2", "#00C7BE", "#FF9F0A", "#FF453A"]
    static let defaultHeadingColors = ["#0A84FF", "#BF5AF2", "#00C7BE", "#FF9F0A", "#FF375F", "#5E5CE6"]
    static let extendedTextColors = [
        "#00C7FF", "#30D158", "#A8E10C", "#FFD60A", "#FF375F",
        "#FF2DFF", "#5E5CE6", "#FF6B6B", "#FFC400", "#63E6BE",
        "#64D2FF", "#D0FD3E", "#FF7A00", "#F72585", "#9B5DE5"
    ]

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    var outlineVisible: Bool {
        didSet { defaults.set(outlineVisible, forKey: Self.outlineKey) }
    }
    var highlightHex: String {
        didSet { defaults.set(highlightHex, forKey: Self.highlightKey) }
    }
    var boldShortcut: MarkdownShortcut { didSet { defaults.set(boldShortcut.rawValue, forKey: Self.boldShortcutKey) } }
    var italicShortcut: MarkdownShortcut { didSet { defaults.set(italicShortcut.rawValue, forKey: Self.italicShortcutKey) } }
    var highlightShortcut: MarkdownShortcut { didSet { defaults.set(highlightShortcut.rawValue, forKey: Self.highlightShortcutKey) } }
    var codeShortcut: MarkdownShortcut { didSet { defaults.set(codeShortcut.rawValue, forKey: Self.codeShortcutKey) } }
    var linkShortcut: MarkdownShortcut { didSet { defaults.set(linkShortcut.rawValue, forKey: Self.linkShortcutKey) } }
    var textColorPresets: [String] { didSet { defaults.set(textColorPresets, forKey: Self.textColorPresetsKey) } }
    var headingColors: [String] { didSet { defaults.set(headingColors, forKey: Self.headingColorsKey) } }
    private var appShortcuts: [String: String] {
        didSet { defaults.set(appShortcuts, forKey: Self.appShortcutsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppAppearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "system") ?? .system
        outlineVisible = defaults.object(forKey: Self.outlineKey) as? Bool ?? true
        highlightHex = defaults.string(forKey: Self.highlightKey) ?? "#FFD60A"
        boldShortcut = MarkdownShortcut(rawValue: defaults.string(forKey: Self.boldShortcutKey) ?? "commandB")
        italicShortcut = MarkdownShortcut(rawValue: defaults.string(forKey: Self.italicShortcutKey) ?? "commandI")
        highlightShortcut = MarkdownShortcut(rawValue: defaults.string(forKey: Self.highlightShortcutKey) ?? "commandShiftH")
        codeShortcut = MarkdownShortcut(rawValue: defaults.string(forKey: Self.codeShortcutKey) ?? "commandE")
        linkShortcut = MarkdownShortcut(rawValue: defaults.string(forKey: Self.linkShortcutKey) ?? "commandK")
        let savedPresets = defaults.stringArray(forKey: Self.textColorPresetsKey) ?? []
        textColorPresets = savedPresets.count == 5 ? savedPresets : Self.defaultTextColorPresets
        let savedHeadingColors = defaults.stringArray(forKey: Self.headingColorsKey) ?? []
        headingColors = savedHeadingColors.count == 6 ? savedHeadingColors : Self.defaultHeadingColors
        appShortcuts = defaults.dictionary(forKey: Self.appShortcutsKey) as? [String: String] ?? [:]
    }

    func shortcut(for action: ShortcutAction) -> AppShortcut {
        switch action {
        case .bold: return boldShortcut
        case .italic: return italicShortcut
        case .highlight: return highlightShortcut
        case .inlineCode: return codeShortcut
        case .link: return linkShortcut
        default: return AppShortcut(rawValue: appShortcuts[action.rawValue] ?? action.defaultShortcut.rawValue)
        }
    }

    func setShortcut(_ shortcut: AppShortcut, for action: ShortcutAction) {
        switch action {
        case .bold: boldShortcut = shortcut
        case .italic: italicShortcut = shortcut
        case .highlight: highlightShortcut = shortcut
        case .inlineCode: codeShortcut = shortcut
        case .link: linkShortcut = shortcut
        default: appShortcuts[action.rawValue] = shortcut.rawValue
        }
    }

    func restoreDefaultShortcuts() {
        appShortcuts = [:]
        boldShortcut = ShortcutAction.bold.defaultShortcut
        italicShortcut = ShortcutAction.italic.defaultShortcut
        highlightShortcut = ShortcutAction.highlight.defaultShortcut
        codeShortcut = ShortcutAction.inlineCode.defaultShortcut
        linkShortcut = ShortcutAction.link.defaultShortcut
    }
}
