import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryItem.title) private var libraryItems: [LibraryItem]
    @Bindable var note: LibraryItem
    let outlineState: NoteOutlineState
    @State private var showsHighlightPalette = false
    @State private var showsTextColorPalette = false
    @State private var autoCardTask: Task<Void, Never>?
    @State private var generatedMessage: String?
    @State private var showsDeckChooser = false

    private var decks: [LibraryItem] { libraryItems.filter { $0.kind == .deck && $0.trashedAt == nil } }
    private var statistics: NoteStatistics { LibraryFeatures.noteStatistics(note.noteMarkdown) }

    var body: some View {
        VStack(spacing: 0) {
            noteHeader
            Divider()
            MarkdownTextView(
                text: $note.noteMarkdown,
                configuration: .note,
                controller: outlineState.controller,
                highlightHex: preferences.highlightHex,
                headingColors: preferences.headingColors,
                onHeadingsChange: { outlineState.headings = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: note.noteMarkdown) {
                note.modifiedAt = .now
                scheduleAutomaticCards()
            }
            .accessibilityLabel("Note editor")
            statusBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .markdownBold)) { _ in outlineState.controller.bold() }
        .onReceive(NotificationCenter.default.publisher(for: .markdownItalic)) { _ in outlineState.controller.italic() }
        .onReceive(NotificationCenter.default.publisher(for: .markdownHighlight)) { _ in outlineState.controller.highlight() }
        .onReceive(NotificationCenter.default.publisher(for: .markdownCode)) { _ in outlineState.controller.inlineCode() }
        .onReceive(NotificationCenter.default.publisher(for: .markdownLink)) { _ in outlineState.controller.link() }
        .onReceive(NotificationCenter.default.publisher(for: .chooseLinkedDeck)) { _ in showsDeckChooser = true }
        .onReceive(NotificationCenter.default.publisher(for: .exportMarkdown)) { _ in export(.markdown) }
        .onReceive(NotificationCenter.default.publisher(for: .exportPlainText)) { _ in export(.plainText) }
        .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in export(.pdf) }
        .confirmationDialog("Choose a card deck", isPresented: $showsDeckChooser, titleVisibility: .visible) {
            Button("None") { note.linkedDeckID = nil }
            ForEach(decks) { deck in
                Button(deck.title) { note.linkedDeckID = deck.id; scheduleAutomaticCards() }
            }
        } message: {
            Text("Lines written as front :: back will create cards in the selected deck.")
        }
        .onDisappear { autoCardTask?.cancel() }
    }

    private var noteHeader: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Note title", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.title2.bold())
                    .accessibilityLabel("Note title")
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        Button("Heading 1") { outlineState.controller.heading(level: 1) }
                        Button("Heading 2") { outlineState.controller.heading(level: 2) }
                        Button("Heading 3") { outlineState.controller.heading(level: 3) }
                        Button("Heading 4") { outlineState.controller.heading(level: 4) }
                    } label: { Label("Heading", systemImage: "textformat.size") }
                    .menuStyle(.borderlessButton)
                    .hoverFeedback()

                    Divider().frame(height: 18)
                    formatButton("Bold", icon: "bold", action: outlineState.controller.bold)
                    formatButton("Italic", icon: "italic", action: outlineState.controller.italic)
                    formatButton("Code", icon: "chevron.left.forwardslash.chevron.right", action: outlineState.controller.inlineCode)
                    formatButton("Link", icon: "link", action: outlineState.controller.link)

                    Divider().frame(height: 18)
                    Button { showsHighlightPalette.toggle() } label: {
                        Label("Highlight", systemImage: "highlighter")
                    }
                    .buttonStyle(.borderless)
                    .help("Highlight color")
                    .accessibilityLabel("Highlight color")
                    .hoverFeedback()
                    .popover(isPresented: $showsHighlightPalette, arrowEdge: .bottom) {
                        HighlightPaletteView { hex in
                            applyHighlight(hex)
                            showsHighlightPalette = false
                        }
                    }

                    Button { showsTextColorPalette.toggle() } label: {
                        Label("Text Color", systemImage: "paintpalette")
                    }
                    .buttonStyle(.borderless)
                    .hoverFeedback()
                    .popover(isPresented: $showsTextColorPalette, arrowEdge: .bottom) {
                        @Bindable var preferences = preferences
                        TextColorPaletteView(presets: $preferences.textColorPresets) { hex in
                            outlineState.controller.color(hex)
                            showsTextColorPalette = false
                        }
                    }

                    Divider().frame(height: 18)
                    Menu {
                        Button("None") { note.linkedDeckID = nil }
                        if !decks.isEmpty { Divider() }
                        ForEach(decks) { deck in
                            Button { note.linkedDeckID = deck.id; scheduleAutomaticCards() } label: {
                                if note.linkedDeckID == deck.id { Label(deck.title, systemImage: "checkmark") } else { Text(deck.title) }
                            }
                        }
                    } label: {
                        Label(linkedDeck?.title ?? "Card Deck", systemImage: "rectangle.stack.badge.plus")
                    }
                    .menuStyle(.borderlessButton).hoverFeedback().help("Assign a deck for front :: back lines")

                    Menu {
                        ForEach(NoteExporter.Format.allCases) { format in
                            Button(format.title) { NoteExporter.export(note: note, format: format) }
                        }
                    } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .menuStyle(.borderlessButton).hoverFeedback()
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var linkedDeck: LibraryItem? { decks.first { $0.id == note.linkedDeckID } }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text("\(statistics.words) words")
            Text("\(statistics.characters) characters")
            Text("\(statistics.readingMinutes) min read")
            if let linkedDeck {
                Divider().frame(height: 13)
                Label(linkedDeck.title, systemImage: "rectangle.stack")
                Text("Use front :: back to add cards").foregroundStyle(.tertiary)
            }
            Spacer()
            if let generatedMessage { Text(generatedMessage).foregroundStyle(.green) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .accessibilityElement(children: .combine)
    }

    private func scheduleAutomaticCards() {
        autoCardTask?.cancel()
        guard linkedDeck != nil else { return }
        autoCardTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            generateAutomaticCards()
        }
    }

    private func generateAutomaticCards() {
        guard let deck = linkedDeck else { return }
        var known = note.generatedCardSignatures
        let additions = AutoCardParser.candidates(in: note.noteMarkdown).filter { !known.contains($0.signature) }
        guard !additions.isEmpty else { return }
        var index = (deck.cards.map(\.sortIndex).max() ?? -1) + 1
        for candidate in additions {
            let card = Flashcard(front: candidate.front, back: candidate.back, sortIndex: index, deck: deck)
            modelContext.insert(card)
            deck.cards.append(card)
            known.insert(candidate.signature)
            index += 1
        }
        note.generatedCardSignatures = known
        deck.modifiedAt = .now
        generatedMessage = "Added \(additions.count) card\(additions.count == 1 ? "" : "s")"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            generatedMessage = nil
        }
    }

    private func formatButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }
            .buttonStyle(.borderless).help(title).accessibilityLabel(title)
            .hoverFeedback(compact: true)
    }

    private func applyHighlight(_ hex: String) {
        preferences.highlightHex = hex
        outlineState.controller.highlight()
    }

    private func export(_ format: NoteExporter.Format) {
        NoteExporter.export(note: note, format: format)
    }
}

private struct HighlightPaletteView: View {
    let colors = ["#FFD60A", "#34C759", "#64D2FF", "#FF6482"]
    let onChoose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlight Color").font(.headline)
            HStack(spacing: 10) {
                ForEach(colors, id: \.self) { hex in
                    ColorSwatch(hex: hex, accessibilityName: "Highlight \(hex)") { onChoose(hex) }
                }
            }
        }
        .padding(14)
    }
}

private struct TextColorPaletteView: View {
    @Binding var presets: [String]
    let onChoose: (String) -> Void
    @State private var isCustomizing = false
    @State private var selectedPreset = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Text Color").font(.headline)
                Spacer()
                Button(isCustomizing ? "Done" : "Customize Presets") { isCustomizing.toggle() }
                    .buttonStyle(.borderless)
                    .hoverFeedback(compact: true)
            }

            Text("PRESETS").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(presets.enumerated()), id: \.offset) { index, hex in
                    ColorSwatch(
                        hex: hex,
                        isSelected: isCustomizing && selectedPreset == index,
                        accessibilityName: "Preset \(index + 1)"
                    ) {
                        if isCustomizing {
                            selectedPreset = index
                        } else {
                            onChoose(hex)
                        }
                    }
                }
            }

            Divider()
            Text(isCustomizing ? "Choose a color below for preset \(selectedPreset + 1)" : "MORE COLORS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 9), count: 5), spacing: 9) {
                ForEach(Preferences.extendedTextColors, id: \.self) { hex in
                    ColorSwatch(hex: hex, accessibilityName: "Text color \(hex)") {
                        if isCustomizing {
                            guard presets.indices.contains(selectedPreset) else { return }
                            presets[selectedPreset] = hex
                        } else {
                            onChoose(hex)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 230)
    }
}

private struct ColorSwatch: View {
    let hex: String
    var isSelected = false
    let accessibilityName: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(width: 28, height: 24)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.14) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.primary : Color.primary.opacity(0.22), lineWidth: isSelected ? 2.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityName)
    }

    private var color: Color {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = Int(value, radix: 16) else { return .primary }
        return Color(
            red: Double((number >> 16) & 0xff) / 255,
            green: Double((number >> 8) & 0xff) / 255,
            blue: Double(number & 0xff) / 255
        )
    }
}
