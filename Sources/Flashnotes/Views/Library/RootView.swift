import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \LibraryFolder.sortIndex) private var folders: [LibraryFolder]
    @Query(sort: \LibraryItem.modifiedAt, order: .reverse) private var allItems: [LibraryItem]

    @State private var renameTarget: RenameTarget?
    @State private var librarySelection: Set<UUID> = []
    @State private var reviewDeck: LibraryItem?
    @State private var noteOutlineState = NoteOutlineState()
    @State private var isSidebarVisible = true
    @State private var sidebarWidth: CGFloat = 230
    @State private var sidebarDragStartWidth: CGFloat?
    @State private var showsSearch = false
    @State private var showsCommandPalette = false
    @State private var showsTrash = false
    @State private var folderStyleTarget: LibraryFolder?
    @State private var tagTarget: LibraryItem?

    private var activeFolders: [LibraryFolder] { folders.filter { $0.trashedAt == nil } }
    private var activeItems: [LibraryItem] { allItems.filter { $0.trashedAt == nil && $0.folder?.trashedAt == nil } }

    private var selectedFolder: LibraryFolder? {
        activeFolders.first { $0.id == session.selectedFolderID }
    }

    private var selectedItem: LibraryItem? {
        activeItems.first { $0.id == session.selectedTabID && $0.folder?.id == session.selectedFolderID }
    }

    private var layoutContent: some View {
        @Bindable var session = session
        return Group {
            if isSidebarVisible {
                HStack(spacing: 0) {
                    sidebarColumn(selection: $session.selectedFolderID)
                        .frame(width: sidebarWidth)
                    sidebarResizeHandle
                    detailPane(selectedTabID: $session.selectedTabID)
                        .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailPane(selectedTabID: $session.selectedTabID)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .hoverFeedback(compact: true)
                }
                .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                .accessibilityLabel(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            }
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 2) {
                    Button(action: session.goBack) { Image(systemName: "chevron.left").hoverFeedback(compact: true) }
                        .disabled(!session.canGoBack).help("Back")
                    Button(action: session.goForward) { Image(systemName: "chevron.right").hoverFeedback(compact: true) }
                        .disabled(!session.canGoForward).help("Forward")
                }
            }
            ToolbarItem(placement: .navigation) {
                Button(action: navigateHome) {
                    Label("Home", systemImage: "house")
                        .hoverFeedback(compact: true)
                }
                .help("Back to folder")
                .disabled(selectedItem == nil && selectedFolder == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showsSearch = true } label: { Image(systemName: "magnifyingglass").hoverFeedback(compact: true) }
                    .help("Search Library (⇧⌘F)")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Top-Level Folder", systemImage: "folder.badge.plus", action: createFolder)
                    Button("Subfolder", systemImage: "folder.badge.plus") {
                        if let selectedFolder { createSubfolder(selectedFolder) }
                    }
                    .disabled(selectedFolder == nil)
                    Divider()
                    Button("Flashcard Deck", systemImage: "rectangle.stack.badge.plus") { createItem(.deck) }
                        .disabled(selectedFolder == nil)
                    Button("Note", systemImage: "note.text.badge.plus") { createItem(.note) }
                        .disabled(selectedFolder == nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .frame(minWidth: 62)
                    .padding(.horizontal, 3)
                    .hoverFeedback(compact: true)
                }
                .accessibilityLabel("Create new folder, deck, or note")
                .menuIndicator(.hidden)
            }
        }
    }

    private var presentationContent: some View {
        layoutContent
        .sheet(item: $renameTarget) { target in
            RenameSheet(title: target.title, initialName: target.name) { target.rename(to: $0) }
        }
        .sheet(item: $reviewDeck) { deck in
            ReviewContainerView(deck: deck)
        }
        .sheet(isPresented: $showsSearch) {
            GlobalSearchView(folders: activeFolders, items: activeItems, onOpenFolder: openFolder, onOpenItem: session.open)
        }
        .sheet(isPresented: $showsCommandPalette) {
            CommandPaletteView(actions: commandActions)
        }
        .sheet(isPresented: $showsTrash) {
            TrashView(
                folders: trashedRootFolders,
                items: individuallyTrashedItems,
                onRestoreFolder: restoreFolder,
                onRestoreItem: restoreItem,
                onDeleteFolder: permanentlyDeleteFolder,
                onDeleteItem: permanentlyDeleteItem
            )
        }
        .sheet(item: $folderStyleTarget) { FolderStyleSheet(folder: $0) }
        .sheet(item: $tagTarget) { TagEditorSheet(item: $0) }
    }

    private var primaryEventContent: some View {
        presentationContent
        .onAppear(perform: repairSession)
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in createFolder() }
        .onReceive(NotificationCenter.default.publisher(for: .newDeck)) { _ in createItem(.deck) }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in
            if selectedItem?.kind == .deck {
                NotificationCenter.default.post(name: .newCard, object: nil)
            } else {
                createItem(.note)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
            if let id = session.selectedTabID { session.close(id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startReview)) { _ in
            if selectedItem?.kind == .deck { reviewDeck = selectedItem }
        }
    }

    var body: some View {
        primaryEventContent
        .onReceive(NotificationCenter.default.publisher(for: .showLibrarySearch)) { _ in showsSearch = true }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in showsCommandPalette = true }
        .onReceive(NotificationCenter.default.publisher(for: .navigateBack)) { _ in session.goBack() }
        .onReceive(NotificationCenter.default.publisher(for: .navigateForward)) { _ in session.goForward() }
        .onReceive(NotificationCenter.default.publisher(for: .navigateHome)) { _ in showLibraryHome() }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in toggleSidebar() }
        .onReceive(NotificationCenter.default.publisher(for: .openTrash)) { _ in showsTrash = true }
        .onReceive(NotificationCenter.default.publisher(for: .moveSelectionToTrash)) { _ in moveCurrentSelectionToTrash() }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFavorite)) { _ in toggleCurrentFavorite() }
        .onReceive(NotificationCenter.default.publisher(for: .editTags)) { _ in if let selectedItem { tagTarget = selectedItem } }
        .onReceive(NotificationCenter.default.publisher(for: .editFolderAppearance)) { _ in if let selectedFolder { folderStyleTarget = selectedFolder } }
        .onReceive(NotificationCenter.default.publisher(for: .cycleFolderSort)) { _ in cycleCurrentFolderSort() }
        .onReceive(NotificationCenter.default.publisher(for: .reverseFolderSort)) { _ in selectedFolder?.sortAscending.toggle() }
        .onChange(of: selectedItem?.id) {
            noteOutlineState.headings = []
        }
    }

    private func toggleSidebar() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            isSidebarVisible.toggle()
        }
    }

    private func moveCurrentSelectionToTrash() {
        if !librarySelection.isEmpty {
            deleteLibrarySelection(librarySelection)
        } else if let selectedItem {
            deleteItemImmediately(selectedItem)
        } else if let selectedFolder {
            deleteFolderImmediately(selectedFolder)
        }
    }

    private func toggleCurrentFavorite() {
        if let selectedItem { toggleItemFavorite(selectedItem) }
        else if let selectedFolder { toggleFolderFavorite(selectedFolder) }
    }

    private func cycleCurrentFolderSort() {
        guard let selectedFolder,
              let index = LibrarySortMode.allCases.firstIndex(of: selectedFolder.sortMode) else { return }
        selectedFolder.sortMode = LibrarySortMode.allCases[(index + 1) % LibrarySortMode.allCases.count]
    }

    private var sidebarResizeHandle: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .frame(width: 7)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = sidebarDragStartWidth ?? sidebarWidth
                    if sidebarDragStartWidth == nil { sidebarDragStartWidth = sidebarWidth }
                    sidebarWidth = min(320, max(180, start + value.translation.width))
                }
                .onEnded { _ in sidebarDragStartWidth = nil }
        )
        .help("Drag to resize the sidebar")
        .accessibilityLabel("Resize sidebar")
    }

    @ViewBuilder
    private func sidebarColumn(selection: Binding<UUID?>) -> some View {
        if selectedItem?.kind == .note {
            SidebarVerticalSplit {
                librarySidebar(selection: selection)
            } lower: {
                NoteOutlinePane(state: noteOutlineState)
            }
        } else {
            librarySidebar(selection: selection)
        }
    }

    private func detailPane(selectedTabID: Binding<UUID?>) -> some View {
        VStack(spacing: 0) {
            BreadcrumbBar(folder: selectedFolder, item: selectedItem, onHome: showLibraryHome, onFolder: openFolder)
            Divider()
            TabStrip(
                items: session.openTabIDs.compactMap { id in activeItems.first { $0.id == id && $0.folder?.id == session.selectedFolderID } },
                selectedID: selectedTabID,
                onClose: session.close
            )
            Divider()
            if let selectedItem {
                ItemDetailView(item: selectedItem, reviewDeck: $reviewDeck, noteOutlineState: noteOutlineState)
                    .id(selectedItem.id)
            } else if let selectedFolder {
                FolderContentsView(
                    folder: selectedFolder,
                    showsWelcome: true,
                    sessionQuote: session.sessionQuote,
                    sessionGreeting: session.sessionGreeting,
                    onOpenFolder: openFolder,
                    onOpen: session.open,
                    onCreateDeck: { createItem(.deck) },
                    onCreateNote: { createItem(.note) },
                    onRename: { renameTarget = .item($0) },
                    onDuplicate: duplicateItem,
                    onDelete: deleteItemImmediately,
                    onToggleFavorite: toggleItemFavorite,
                    onEditTags: { tagTarget = $0 }
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        WelcomeGreetingView(greeting: session.sessionGreeting)
                            .padding(.top, 34)
                        EmptyStateView(
                            icon: "square.stack.3d.up",
                            title: "Start your library",
                            message: "Create a folder to begin organizing decks and notes.",
                            actionTitle: "Create Folder",
                            action: createFolder
                        )
                        .accessibilityIdentifier("Library Empty State")
                        .frame(minHeight: 230)
                        SessionQuoteView(quote: session.sessionQuote)
                            .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func librarySidebar(selection: Binding<UUID?>) -> some View {
        FolderSidebar(
            folders: activeFolders,
            selection: selection,
            selectedItemID: selectedItem?.id,
            multiSelection: $librarySelection,
            onSelect: openFolder,
            onOpenItem: session.open,
            onCreate: createFolder,
            onCreateChild: createSubfolder,
            onCreateDeck: { createItem(.deck, in: $0) },
            onCreateNote: { createItem(.note, in: $0) },
            onRename: { renameTarget = .folder($0) },
            onDelete: deleteFolderImmediately,
            onMove: moveFolder,
            onRenameItem: { renameTarget = .item($0) },
            onDuplicateItem: duplicateItem,
            onDeleteItem: deleteItemImmediately,
            onDeleteSelection: deleteLibrarySelection,
            onDropEntry: moveLibraryEntry,
            onToggleFolderFavorite: toggleFolderFavorite,
            onToggleItemFavorite: toggleItemFavorite,
            onStyleFolder: { folderStyleTarget = $0 },
            onEditTags: { tagTarget = $0 },
            onShowTrash: { showsTrash = true }
        )
    }

    private func repairSession() {
        let folderIDs = Set(activeFolders.map(\.id))
        let itemIDs = Set(activeItems.map(\.id))
        session.openTabIDs.removeAll { !itemIDs.contains($0) }
        if session.selectedFolderID.map({ !folderIDs.contains($0) }) ?? true {
            session.selectedFolderID = activeFolders.first?.id
        }
        if session.selectedTabID.map({ !itemIDs.contains($0) }) ?? false {
            session.selectedTabID = session.openTabIDs.last
        }
        if let selectedItem { session.open(selectedItem) }
    }

    private func createFolder() {
        let roots = activeFolders.filter { $0.parent == nil }
        let folder = LibraryFolder(name: "New Folder", sortIndex: (roots.map(\.sortIndex).max() ?? -1) + 1)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            modelContext.insert(folder)
            session.selectedFolderID = folder.id
        }
        renameTarget = .folder(folder)
    }

    private func createSubfolder(_ parent: LibraryFolder) {
        let folder = LibraryFolder(
            name: "New Subfolder",
            sortIndex: (parent.children.map(\.sortIndex).max() ?? -1) + 1,
            parent: parent
        )
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            modelContext.insert(folder)
            parent.children.append(folder)
            session.selectedFolderID = folder.id
            session.selectedTabID = nil
        }
        renameTarget = .folder(folder)
    }

    private func openFolder(_ folder: LibraryFolder) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            session.navigate(to: folder)
        }
    }

    private func navigateHome() {
        if selectedItem != nil {
            session.navigate(to: selectedFolder)
            return
        }
        guard var destination = selectedFolder, destination.parent != nil else { return }
        while let parent = destination.parent { destination = parent }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            session.navigate(to: destination)
        }
    }

    private func showLibraryHome() {
        if var destination = selectedFolder {
            while let parent = destination.parent { destination = parent }
            session.navigate(to: destination)
        } else if let first = activeFolders.first(where: { $0.parent == nil }) {
            session.navigate(to: first)
        }
    }

    private var commandActions: [CommandPaletteView.Action] {
        var actions: [CommandPaletteView.Action] = [
            .init(title: "Search Library", icon: "magnifyingglass", keywords: "find global", perform: { showsSearch = true }),
            .init(title: "New Top-Level Folder", icon: "folder.badge.plus", keywords: "create", perform: createFolder),
            .init(title: "Open Trash", icon: "trash", keywords: "deleted restore", perform: { showsTrash = true })
        ]
        if selectedFolder != nil {
            actions.append(.init(title: "New Note", icon: "note.text.badge.plus", keywords: "create", perform: { createItem(.note) }))
            actions.append(.init(title: "New Flashcard Deck", icon: "rectangle.stack.badge.plus", keywords: "create cards", perform: { createItem(.deck) }))
        }
        actions += activeItems.prefix(30).map { item in
            .init(title: "Open \(item.title)", icon: item.kind == .deck ? "rectangle.stack" : "note.text", keywords: LibraryFeatures.searchText(for: item), perform: { session.open(item) })
        }
        return actions
    }

    private var trashedRootFolders: [LibraryFolder] {
        folders.filter { $0.trashedAt != nil && ($0.parent == nil || $0.parent?.trashedAt == nil) }.sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
    }

    private var individuallyTrashedItems: [LibraryItem] {
        allItems.filter { $0.trashedAt != nil && $0.folder?.trashedAt == nil }.sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
    }

    private func createItem(_ kind: LibraryItemKind, in destinationFolder: LibraryFolder? = nil) {
        guard let folder = destinationFolder ?? selectedFolder else { return }
        let title = kind == .deck ? "Untitled Deck" : "Untitled Note"
        let item = LibraryItem(title: title, kind: kind, sortIndex: (folder.items.map(\.sortIndex).max() ?? -1) + 1, folder: folder)
        modelContext.insert(item)
        folder.items.append(item)
        session.open(item)
        renameTarget = .item(item)
    }

    private func moveFolder(_ folder: LibraryFolder, by offset: Int) {
        var siblings = (folder.parent?.children ?? folders.filter { $0.parent == nil })
            .sorted { $0.sortIndex < $1.sortIndex }
        guard let current = siblings.firstIndex(where: { $0.id == folder.id }) else { return }
        let destination = current + offset
        guard siblings.indices.contains(destination) else { return }
        siblings.swapAt(current, destination)
        for (index, sibling) in siblings.enumerated() { sibling.sortIndex = index }
    }

    private func moveLibraryEntry(_ payload: String, into destination: LibraryFolder) -> Bool {
        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return false }

        if parts[0] == "item", let item = allItems.first(where: { $0.id == id }) {
            guard item.folder?.id != destination.id else { return false }
            item.folder?.items.removeAll { $0.id == item.id }
            item.folder = destination
            item.sortIndex = (destination.items.map(\.sortIndex).max() ?? -1) + 1
            if !destination.items.contains(where: { $0.id == item.id }) { destination.items.append(item) }
            item.modifiedAt = .now
            return true
        }

        if parts[0] == "folder", let folder = folders.first(where: { $0.id == id }) {
            guard folder.id != destination.id,
                  !folderSubtree(folder).contains(where: { $0.id == destination.id }) else { return false }
            folder.parent?.children.removeAll { $0.id == folder.id }
            folder.parent = destination
            folder.sortIndex = (destination.children.map(\.sortIndex).max() ?? -1) + 1
            if !destination.children.contains(where: { $0.id == folder.id }) { destination.children.append(folder) }
            return true
        }
        return false
    }

    private func duplicateItem(_ source: LibraryItem) {
        guard let folder = source.folder else { return }
        let copy = LibraryItem(title: source.title + " Copy", kind: source.kind, sortIndex: (folder.items.map(\.sortIndex).max() ?? -1) + 1, folder: folder)
        let attachmentStore = AttachmentStore()
        copy.noteMarkdown = attachmentStore.duplicateReferences(in: source.noteMarkdown)
        modelContext.insert(copy)
        folder.items.append(copy)
        for card in source.cards.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let newCard = Flashcard(
                front: attachmentStore.duplicateReferences(in: card.front),
                back: attachmentStore.duplicateReferences(in: card.back),
                sortIndex: card.sortIndex,
                deck: copy
            )
            modelContext.insert(newCard)
            copy.cards.append(newCard)
        }
        session.open(copy)
    }

    private func deleteFolderImmediately(_ folder: LibraryFolder) {
        moveToTrash(.folder(folder))
    }

    private func deleteItemImmediately(_ item: LibraryItem) {
        moveToTrash(.item(item))
    }

    private func deleteLibrarySelection(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let selectedFolders = folders.filter { ids.contains($0.id) }
        let selectedFolderIDs = Set(selectedFolders.map(\.id))
        let topLevelSelectedFolders = selectedFolders.filter { folder in
            var ancestor = folder.parent
            while let value = ancestor {
                if selectedFolderIDs.contains(value.id) { return false }
                ancestor = value.parent
            }
            return true
        }
        let coveredItemIDs = Set(topLevelSelectedFolders.flatMap(folderSubtree).flatMap(\.items).map(\.id))
        let selectedItems = allItems.filter { ids.contains($0.id) && !coveredItemIDs.contains($0.id) }

        selectedItems.forEach { moveToTrash(.item($0)) }
        topLevelSelectedFolders.forEach { moveToTrash(.folder($0)) }
        librarySelection.removeAll()
    }

    private func moveToTrash(_ target: DeleteTarget) {
        switch target {
        case .folder(let folder):
            let subtree = folderSubtree(folder)
            let subtreeItems = subtree.flatMap(\.items)
            let ids = Set(subtreeItems.map(\.id))
            session.removeReferences(to: ids)
            subtree.forEach { $0.trashedAt = .now }
            subtreeItems.forEach { $0.trashedAt = .now }
            if subtree.contains(where: { $0.id == session.selectedFolderID }) {
                session.selectedFolderID = folder.parent?.trashedAt == nil ? folder.parent?.id : activeFolders.first { candidate in
                    !subtree.contains(where: { $0.id == candidate.id })
                }?.id
            }
        case .item(let item):
            session.removeReferences(to: [item.id])
            item.trashedAt = .now
        }
        librarySelection.subtract(ids(for: target))
    }

    private func restoreFolder(_ folder: LibraryFolder) {
        for value in folderSubtree(folder) {
            value.trashedAt = nil
            value.items.forEach { $0.trashedAt = nil }
        }
        if folder.parent?.trashedAt != nil { folder.parent = nil }
    }

    private func restoreItem(_ item: LibraryItem) { item.trashedAt = nil }

    private func permanentlyDeleteFolder(_ folder: LibraryFolder) {
        let subtreeItems = folderSubtree(folder).flatMap(\.items)
        AttachmentStore().removeAttachments(referencedIn: subtreeItems.flatMap { [$0.noteMarkdown] + $0.cards.flatMap { [$0.front, $0.back] } })
        modelContext.delete(folder)
    }

    private func permanentlyDeleteItem(_ item: LibraryItem) {
        AttachmentStore().removeAttachments(referencedIn: [item.noteMarkdown] + item.cards.flatMap { [$0.front, $0.back] })
        modelContext.delete(item)
    }

    private func toggleFolderFavorite(_ folder: LibraryFolder) { folder.favoriteAt = folder.favoriteAt == nil ? .now : nil }
    private func toggleItemFavorite(_ item: LibraryItem) { item.favoriteAt = item.favoriteAt == nil ? .now : nil }

    private func ids(for target: DeleteTarget) -> Set<UUID> {
        switch target {
        case .folder(let folder):
            return Set(folderSubtree(folder).flatMap { [$0.id] + $0.items.map(\.id) })
        case .item(let item):
            return [item.id]
        }
    }

    private func folderSubtree(_ folder: LibraryFolder) -> [LibraryFolder] {
        [folder] + folder.children.flatMap(folderSubtree)
    }
}

private enum RenameTarget: Identifiable {
    case folder(LibraryFolder)
    case item(LibraryItem)
    var id: UUID { switch self { case .folder(let value): value.id; case .item(let value): value.id } }
    var title: String { switch self { case .folder: "Rename Folder"; case .item: "Rename Item" } }
    var name: String { switch self { case .folder(let value): value.name; case .item(let value): value.title } }
    func rename(to name: String) {
        switch self {
        case .folder(let value): value.name = name; value.modifiedAt = .now
        case .item(let value): value.title = name; value.modifiedAt = .now
        }
    }
}

private enum DeleteTarget {
    case folder(LibraryFolder)
    case item(LibraryItem)
}

private struct RenameSheet: View {
    let title: String
    @State var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        _name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save", action: save).buttonStyle(.borderedProminent).disabled(name.trimmed.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 380)
    }

    private func save() { onSave(name.trimmed); dismiss() }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
