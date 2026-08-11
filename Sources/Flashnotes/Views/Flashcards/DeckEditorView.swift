import SwiftData
import SwiftUI

struct DeckEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: LibraryItem
    let onStartReview: () -> Void
    @State private var selectedCardIDs: Set<UUID> = []

    private var cards: [Flashcard] { deck.cards.sorted { $0.sortIndex < $1.sortIndex } }
    private var selectedCard: Flashcard? {
        guard selectedCardIDs.count == 1, let id = selectedCardIDs.first else { return nil }
        return cards.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            deckHeader
            Divider()

            if cards.isEmpty {
                EmptyStateView(
                    icon: "rectangle.stack.badge.plus",
                    title: "Add your first card",
                    message: "Create a front and back, then start reviewing.",
                    actionTitle: "Add Card",
                    action: addCard
                )
            } else {
                GeometryReader { geometry in
                    if geometry.size.width < 720 {
                        VStack(spacing: 0) {
                            cardList.frame(height: min(220, max(150, geometry.size.height * 0.28)))
                            Divider()
                            editorContent
                        }
                    } else {
                        HSplitView {
                            cardList.frame(minWidth: 180, idealWidth: 230, maxWidth: 300)
                            editorContent.frame(minWidth: 320)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: repairSelection)
        .onChange(of: cards.map(\.id)) { repairSelection() }
        .onReceive(NotificationCenter.default.publisher(for: .newCard)) { _ in addCard() }
    }

    private var deckHeader: some View {
        HStack(spacing: 12) {
            TextField("Deck title", text: $deck.title)
                .textFieldStyle(.plain)
                .font(.title2.bold())
                .lineLimit(1)
                .onChange(of: deck.title) { deck.modifiedAt = .now }
                .accessibilityLabel("Deck title")
            Spacer(minLength: 8)
            Button("Review", systemImage: "play.fill", action: onStartReview)
                .buttonStyle(.borderedProminent)
                .hoverFeedback()
                .disabled(cards.isEmpty)
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var editorContent: some View {
        if selectedCardIDs.count > 1 {
            VStack(spacing: 14) {
                Image(systemName: "rectangle.stack.fill").font(.system(size: 34)).foregroundStyle(.tint)
                Text("\(selectedCardIDs.count) cards selected").font(.title2.bold())
                Button("Delete Selected", systemImage: "trash", role: .destructive) {
                    deleteCards(selectedCardIDs)
                }
                .hoverFeedback()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedCard {
            CardEditor(card: selectedCard) { deck.modifiedAt = .now }
        } else {
            EmptyStateView(
                icon: "rectangle.stack",
                title: "Select a card",
                message: "Shift-click or Command-click to select several cards."
            )
        }
    }

    private var cardList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CARDS").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("\(cards.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 12).frame(height: 34).background(Color(nsColor: .controlBackgroundColor))

            List(selection: $selectedCardIDs) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary(card.front)).lineLimit(1)
                            Text(summary(card.back)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(card.id)
                    .contextMenu {
                        Button("Duplicate") { duplicate(card) }
                        Button(selectedCardIDs.count > 1 && selectedCardIDs.contains(card.id) ? "Delete Selected" : "Delete", role: .destructive) {
                            deleteCards(selectedCardIDs.count > 1 && selectedCardIDs.contains(card.id) ? selectedCardIDs : [card.id])
                        }
                    }
                }
                .onMove(perform: moveCards)

                DeckAddCardRow(action: addCard)
            }
            .listStyle(.inset)

            HStack(spacing: 12) {
                Spacer()
                if selectedCardIDs.count == 1, let selectedCard {
                    Button { duplicate(selectedCard) } label: { Image(systemName: "plus.square.on.square") }
                        .buttonStyle(.plain).hoverFeedback(compact: true).help("Duplicate selected card")
                }
                if !selectedCardIDs.isEmpty {
                    Button(role: .destructive) { deleteCards(selectedCardIDs) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain).hoverFeedback(compact: true).help("Delete selected cards")
                }
            }
            .padding(10).background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func repairSelection() {
        let valid = Set(cards.map(\.id))
        selectedCardIDs.formIntersection(valid)
        if selectedCardIDs.isEmpty, let first = cards.first { selectedCardIDs = [first.id] }
    }

    private func addCard() {
        let card = Flashcard(sortIndex: (cards.map(\.sortIndex).max() ?? -1) + 1, deck: deck)
        modelContext.insert(card)
        deck.cards.append(card)
        deck.modifiedAt = .now
        selectedCardIDs = [card.id]
    }

    private func duplicate(_ source: Flashcard) {
        let attachmentStore = AttachmentStore()
        let card = Flashcard(
            front: attachmentStore.duplicateReferences(in: source.front),
            back: attachmentStore.duplicateReferences(in: source.back),
            sortIndex: (cards.map(\.sortIndex).max() ?? -1) + 1,
            deck: deck
        )
        modelContext.insert(card)
        deck.cards.append(card)
        deck.modifiedAt = .now
        selectedCardIDs = [card.id]
    }

    private func deleteCards(_ ids: Set<UUID>) {
        let targets = cards.filter { ids.contains($0.id) }
        AttachmentStore().removeAttachments(referencedIn: targets.flatMap { [$0.front, $0.back] })
        targets.forEach(modelContext.delete)
        selectedCardIDs.subtract(ids)
        deck.modifiedAt = .now
        let remaining = cards.filter { !targets.map(\.id).contains($0.id) }
        for (index, card) in remaining.enumerated() { card.sortIndex = index }
        if selectedCardIDs.isEmpty, let first = remaining.first { selectedCardIDs = [first.id] }
    }

    private func moveCards(from offsets: IndexSet, to destination: Int) {
        var reordered = cards
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, card) in reordered.enumerated() { card.sortIndex = index }
        deck.modifiedAt = .now
    }

    private func summary(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: #"!\[[^]]*\]\([^)]+\)"#, with: "[Image]", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ").trimmed
        return cleaned.isEmpty ? "Empty" : cleaned
    }
}

private struct DeckAddCardRow: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .frame(width: 22)
                Text("Add Card")
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08))
                    }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityLabel("Add card")
        .listRowSeparator(.hidden)
    }
}

private struct CardEditor: View {
    @Environment(Preferences.self) private var preferences
    @Bindable var card: Flashcard
    let onChange: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cardSide(title: "Front", text: $card.front)
                Divider()
                cardSide(title: "Back", text: $card.back)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cardSide(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
            MarkdownTextView(
                text: text,
                configuration: .card,
                highlightHex: preferences.highlightHex,
                headingColors: preferences.headingColors,
                onHeadingsChange: nil
            )
                .frame(minHeight: 190, idealHeight: 250)
                .glassOutline(cornerRadius: 9)
                .onChange(of: text.wrappedValue) { onChange() }
                .accessibilityLabel("Card \(title.lowercased())")
        }
    }
}
