import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferences.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("App appearance")

                Text("The library, outline, and outer navigation surfaces use the native macOS sidebar material. The editor and content workspace remain solid.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Highlight color", selection: $preferences.highlightHex) {
                    Text("Yellow").tag("#FFD60A")
                    Text("Mint").tag("#34C759")
                    Text("Blue").tag("#64D2FF")
                    Text("Pink").tag("#FF6482")
                }
                .accessibilityLabel("Default Markdown highlight color")
            }

            shortcutSection("Navigation", actions: [.back, .forward, .home, .toggleSidebar, .search, .commandPalette])
            shortcutSection("Library Shortcuts", actions: [
                .newFolder, .newDeck, .newNote, .openTrash, .moveToTrash, .toggleFavorite,
                .editTags, .folderAppearance, .expandAll, .collapseAll, .cycleSort, .reverseSort
            ])
            shortcutSection("Note and Export Shortcuts", actions: [.chooseLinkedDeck, .exportMarkdown, .exportPlainText, .exportPDF])
            shortcutSection("Editing and Review Shortcuts", actions: [.bold, .italic, .highlight, .inlineCode, .link, .startReview, .closeTab])

            Section {
                if !duplicateShortcuts.isEmpty {
                    Label("Some shortcuts are assigned more than once. Only the currently relevant command will run.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Restore Default Shortcuts") { preferences.restoreDefaultShortcuts() }
            }

            Section("Heading Colors") {
                ForEach(0..<6, id: \.self) { index in
                    ColorPicker(
                        "Heading \(index + 1)",
                        selection: headingColorBinding(index),
                        supportsOpacity: false
                    )
                    .accessibilityLabel("Heading level \(index + 1) color")
                }
                Button("Restore Default Heading Colors") {
                    preferences.headingColors = Preferences.defaultHeadingColors
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 650)
    }

    private func shortcutSection(_ title: String, actions: [ShortcutAction]) -> some View {
        Section(title) {
            ForEach(actions) { action in
                shortcutPicker(action.title, selection: shortcutBinding(action))
            }
        }
    }

    private func shortcutPicker(_ title: String, selection: Binding<AppShortcut>) -> some View {
        Picker(title, selection: selection) {
            ForEach(AppShortcut.allCases) { shortcut in
                Text(shortcut.title).tag(shortcut)
            }
        }
    }

    private func shortcutBinding(_ action: ShortcutAction) -> Binding<AppShortcut> {
        Binding {
            preferences.shortcut(for: action)
        } set: { shortcut in
            preferences.setShortcut(shortcut, for: action)
        }
    }

    private var duplicateShortcuts: Set<AppShortcut> {
        let values = ShortcutAction.allCases.map { preferences.shortcut(for: $0) }.filter { $0 != .none }
        return Set(values.filter { shortcut in values.filter { $0 == shortcut }.count > 1 })
    }

    private func headingColorBinding(_ index: Int) -> Binding<Color> {
        Binding {
            guard preferences.headingColors.indices.contains(index) else { return .primary }
            return Color(hexString: preferences.headingColors[index])
        } set: { color in
            guard preferences.headingColors.indices.contains(index), let hex = color.hexString else { return }
            preferences.headingColors[index] = hex
        }
    }
}

private extension Color {
    init(hexString: String) {
        let value = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = Int(value, radix: 16) else {
            self = .primary
            return
        }
        self.init(
            red: Double((number >> 16) & 0xff) / 255,
            green: Double((number >> 8) & 0xff) / 255,
            blue: Double(number & 0xff) / 255
        )
    }

    var hexString: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}
