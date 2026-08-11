import SwiftUI

struct FolderContentsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var folder: LibraryFolder
    let showsWelcome: Bool
    let sessionQuote: SessionQuote
    let sessionGreeting: String
    let onOpenFolder: (LibraryFolder) -> Void
    let onOpen: (LibraryItem) -> Void
    let onCreateDeck: () -> Void
    let onCreateNote: () -> Void
    let onRename: (LibraryItem) -> Void
    let onDuplicate: (LibraryItem) -> Void
    let onDelete: (LibraryItem) -> Void
    let onToggleFavorite: (LibraryItem) -> Void
    let onEditTags: (LibraryItem) -> Void

    private var items: [LibraryItem] { LibraryFeatures.sortedItems(folder.items, for: folder) }
    private var subfolders: [LibraryFolder] { LibraryFeatures.sortedFolders(folder.children, for: folder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsWelcome {
                welcomeHero
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name).font(.largeTitle.bold())
                    Text(summary).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(LibrarySortMode.allCases) { mode in
                        Button { folder.sortMode = mode } label: {
                            if folder.sortMode == mode { Label(mode.title, systemImage: "checkmark") } else { Text(mode.title) }
                        }
                    }
                    Divider()
                    Button(folder.sortAscending ? "Descending" : "Ascending", systemImage: folder.sortAscending ? "arrow.down" : "arrow.up") { folder.sortAscending.toggle() }
                } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 26, height: 26) }
                .menuIndicator(.hidden).help("Sort contents").hoverFeedback(compact: true)
                Menu {
                    Button("Flashcard Deck", action: onCreateDeck)
                    Button("Note", action: onCreateNote)
                } label: {
                    Label("New", systemImage: "plus")
                        .frame(minWidth: 62)
                }
                .menuIndicator(.hidden)
                .hoverFeedback()
            }
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            homeContent
            .id(folder.id)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: folder.id)
    }

    private var summary: String {
        var parts: [String] = []
        if !subfolders.isEmpty { parts.append("\(subfolders.count) subfolder\(subfolders.count == 1 ? "" : "s")") }
        if !items.isEmpty { parts.append("\(items.count) item\(items.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "Empty folder" : parts.joined(separator: "  •  ")
    }

    private var welcomeHero: some View {
        WelcomeGreetingView(greeting: sessionGreeting)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .glassOutline(cornerRadius: 14)
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    private var homeContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if subfolders.isEmpty && items.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "Nothing here yet",
                            message: "Add a deck or note to this folder.",
                            actionTitle: "New Deck",
                            action: onCreateDeck,
                            secondaryActionTitle: "New Note",
                            secondaryAction: onCreateNote
                        )
                        .frame(maxWidth: .infinity, minHeight: 190)
                    } else {
                        contentsSections
                    }

                    Spacer(minLength: 28)
                    SessionQuoteView(quote: sessionQuote)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
    }

    private var contentsSections: some View {
        VStack(alignment: .leading, spacing: 22) {
                if !subfolders.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SUBFOLDERS")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 14)], spacing: 14) {
                            ForEach(subfolders) { child in
                                SubfolderTile(folder: child) { onOpenFolder(child) }
                            }
                        }
                    }
                }

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTENTS")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(items) { item in
                            LibraryItemRow(item: item) { onOpen(item) }
                                .contextMenu {
                                    Button("Open") { onOpen(item) }
                                    Button("Rename") { onRename(item) }
                                    Button("Duplicate") { onDuplicate(item) }
                                    Button(item.favoriteAt == nil ? "Add to Favorites" : "Remove from Favorites") { onToggleFavorite(item) }
                                    Button("Edit Tags…") { onEditTags(item) }
                                    Divider()
                                    Button("Delete", role: .destructive) { onDelete(item) }
                                }
                        }
                    }
                }
        }
    }

    private struct LibraryItemRow: View {
        let item: LibraryItem
        let action: () -> Void
        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: item.kind == .deck ? "rectangle.stack.fill" : "note.text")
                        .font(.title3).foregroundStyle(.tint).frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.headline)
                        Text(item.kind == .deck ? "\(item.cards.count) cards" : summary(item.noteMarkdown))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if !item.tags.isEmpty {
                            Text(item.tags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                                .font(.caption2).foregroundStyle(.tint).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(item.modifiedAt, style: .date).font(.caption).foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 58)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isHovered ? Color.primary.opacity(0.055) : .clear)
                        }
                }
                .contentShape(Rectangle())
                .glassOutline(cornerRadius: 9)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }

        private func summary(_ text: String) -> String {
            let value = text.replacingOccurrences(of: "\n", with: " ").trimmed
            return value.isEmpty ? "Empty note" : value
        }
    }
}

struct WelcomeGreetingView: View {
    let greeting: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.tint)
            OrganicGradientText(text: greeting, size: 40)
            Text("What would you like to study, Rik?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SubfolderTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let folder: LibraryFolder
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: folder.effectiveSymbolName)
                    .font(.title2)
                    .foregroundStyle(folder.colorHex.map { Color(libraryHex: $0) } ?? Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name).font(.headline).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .glassOutline(cornerRadius: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.primary.opacity(0.055) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    }

    private var detail: String {
        if !folder.children.isEmpty {
            return "\(folder.children.count) subfolder\(folder.children.count == 1 ? "" : "s")"
        }
        return "\(folder.items.count) item\(folder.items.count == 1 ? "" : "s")"
    }
}
