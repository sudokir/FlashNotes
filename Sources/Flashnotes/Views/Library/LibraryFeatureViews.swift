import SwiftUI

struct BreadcrumbBar: View {
    let folder: LibraryFolder?
    let item: LibraryItem?
    let onHome: () -> Void
    let onFolder: (LibraryFolder) -> Void

    private var path: [LibraryFolder] {
        var result: [LibraryFolder] = []
        var current = folder
        while let value = current { result.insert(value, at: 0); current = value.parent }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Button(action: onHome) { Image(systemName: "house").frame(width: 22, height: 22) }
                    .buttonStyle(.plain).hoverFeedback(compact: true).help("Library home")
                ForEach(path) { value in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Button(value.name) { onFolder(value) }
                        .buttonStyle(.plain).foregroundStyle(value.id == folder?.id && item == nil ? .primary : .secondary)
                        .hoverFeedback(compact: true)
                }
                if let item {
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Label(item.title, systemImage: item.kind == .deck ? "rectangle.stack" : "note.text")
                        .lineLimit(1).foregroundStyle(.primary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .frame(height: 30)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
    }
}

struct GlobalSearchView: View {
    let folders: [LibraryFolder]
    let items: [LibraryItem]
    let onOpenFolder: (LibraryFolder) -> Void
    let onOpenItem: (LibraryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope = SearchScope.all

    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case notes = "Notes"
        case decks = "Decks"
        case folders = "Folders"
        var id: String { rawValue }
    }

    private var matchingFolders: [LibraryFolder] {
        guard scope == .all || scope == .folders else { return [] }
        return query.isEmpty ? [] : folders.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    private var matchingItems: [LibraryItem] {
        guard scope != .folders else { return [] }
        return query.isEmpty ? [] : items.filter {
            (scope == .all || (scope == .notes && $0.kind == .note) || (scope == .decks && $0.kind == .deck)) &&
            LibraryFeatures.searchText(for: $0).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search titles, notes, cards, and tags", text: $query)
                    .textFieldStyle(.plain).font(.title3)
                Picker("Scope", selection: $scope) {
                    ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 105)
            }
            .padding(16)
            Divider()
            if query.trimmed.isEmpty {
                ContentUnavailableView("Search your library", systemImage: "magnifyingglass", description: Text("Find folders, notes, deck titles, card text, and tags."))
            } else if matchingFolders.isEmpty && matchingItems.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    if !matchingFolders.isEmpty {
                        Section("Folders") {
                            ForEach(matchingFolders) { folder in
                                resultButton(folder.name, icon: folder.effectiveSymbolName, detail: folderPath(folder)) {
                                    onOpenFolder(folder); dismiss()
                                }
                            }
                        }
                    }
                    if !matchingItems.isEmpty {
                        Section("Content") {
                            ForEach(matchingItems) { item in
                                resultButton(item.title, icon: item.kind == .deck ? "rectangle.stack" : "note.text", detail: itemDetail(item)) {
                                    onOpenItem(item); dismiss()
                                }
                            }
                        }
                    }
                }.listStyle(.inset)
            }
        }
        // Give the sheet a real top-leading layout area. Without this explicit
        // expansion SwiftUI centers the compact search header vertically when
        // there are no results yet.
        .frame(minWidth: 620, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func resultButton(_ title: String, icon: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) { Text(title); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func folderPath(_ folder: LibraryFolder) -> String {
        var names = [folder.name]; var current = folder.parent
        while let value = current { names.insert(value.name, at: 0); current = value.parent }
        return names.joined(separator: " › ")
    }

    private func itemDetail(_ item: LibraryItem) -> String {
        let location = item.folder.map(folderPath) ?? "Library"
        if let tag = item.tags.first { return "\(location)  •  #\(tag)" }
        return location
    }
}

struct CommandPaletteView: View {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let keywords: String
        let perform: () -> Void
    }
    let actions: [Action]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Action] {
        query.isEmpty ? actions : actions.filter { ($0.title + " " + $0.keywords).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "command"); TextField("Type a command or item name", text: $query).textFieldStyle(.plain).font(.title3) }
                .padding(16)
            Divider()
            List(results) { action in
                Button { action.perform(); dismiss() } label: {
                    Label(action.title, systemImage: action.icon).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }.listStyle(.inset)
        }.frame(width: 560, height: 430)
    }
}

struct TrashView: View {
    let folders: [LibraryFolder]
    let items: [LibraryItem]
    let onRestoreFolder: (LibraryFolder) -> Void
    let onRestoreItem: (LibraryItem) -> Void
    let onDeleteFolder: (LibraryFolder) -> Void
    let onDeleteItem: (LibraryItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Trash", systemImage: "trash").font(.title2.bold())
                Spacer(); Button("Done") { dismiss() }
            }.padding(18)
            Divider()
            if folders.isEmpty && items.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash", description: Text("Deleted content can be restored from here."))
            } else {
                List {
                    if !folders.isEmpty {
                        Section("Folders") {
                            ForEach(folders) { folder in
                                trashRow(folder.name, icon: folder.effectiveSymbolName, restore: { onRestoreFolder(folder) }, delete: { onDeleteFolder(folder) })
                            }
                        }
                    }
                    if !items.isEmpty {
                        Section("Notes and Decks") {
                            ForEach(items) { item in
                                trashRow(item.title, icon: item.kind == .deck ? "rectangle.stack" : "note.text", restore: { onRestoreItem(item) }, delete: { onDeleteItem(item) })
                            }
                        }
                    }
                }.listStyle(.inset)
            }
        }.frame(minWidth: 620, minHeight: 460)
    }

    private func trashRow(_ title: String, icon: String, restore: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Button("Restore", action: restore); Button("Delete Permanently", role: .destructive, action: delete) }
    }
}

struct FolderStyleSheet: View {
    @Bindable var folder: LibraryFolder
    @Environment(\.dismiss) private var dismiss
    private let symbols = ["folder.fill", "book.closed.fill", "graduationcap.fill", "brain.head.profile", "atom", "flask.fill", "globe.americas.fill", "music.note", "paintpalette.fill", "briefcase.fill", "star.fill", "heart.fill"]
    private let colors: [String?] = [nil, "#0A84FF", "#BF5AF2", "#30D158", "#FFD60A", "#FF9F0A", "#FF453A", "#FF375F", "#64D2FF", "#8E8E93"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Folder Appearance").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            TextField("Folder name", text: $folder.name)
            Text("SYMBOL").font(.caption.bold()).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(42)), count: 6), spacing: 9) {
                ForEach(symbols, id: \.self) { symbol in
                    Button { folder.symbolName = symbol; folder.modifiedAt = .now } label: {
                        Image(systemName: symbol).frame(width: 36, height: 32).background(folder.effectiveSymbolName == symbol ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).hoverFeedback(compact: true)
                }
            }
            Text("COLOR").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 9) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, hex in
                    Button { folder.colorHex = hex; folder.modifiedAt = .now } label: {
                        Circle().fill(hex.map { Color(libraryHex: $0) } ?? Color.secondary).frame(width: 26, height: 26)
                            .overlay(Circle().stroke(folder.colorHex == hex ? Color.primary : .clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(22).frame(width: 390)
    }
}

struct TagEditorSheet: View {
    @Bindable var item: LibraryItem
    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(item: LibraryItem) { self.item = item; _text = State(initialValue: item.tags.joined(separator: ", ")) }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Tags for “\(item.title)”").font(.headline)
            TextField("study, biology, exam", text: $text).textFieldStyle(.roundedBorder).onSubmit(save)
            Text("Separate tags with commas.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel", role: .cancel) { dismiss() }; Button("Save", action: save).buttonStyle(.borderedProminent) }
        }.padding(22).frame(width: 430)
    }
    private func save() { item.tags = text.split(separator: ",").map(String.init); item.modifiedAt = .now; dismiss() }
}

extension Color {
    init(libraryHex: String) {
        let value = libraryHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = Int(value, radix: 16) ?? 0x8E8E93
        self.init(red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255)
    }
}
