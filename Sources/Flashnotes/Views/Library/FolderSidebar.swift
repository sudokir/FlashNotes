import AppKit
import SwiftUI

struct FolderSidebar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionStore.self) private var session
    let folders: [LibraryFolder]
    @Binding var selection: UUID?
    let selectedItemID: UUID?
    @Binding var multiSelection: Set<UUID>
    let onSelect: (LibraryFolder) -> Void
    let onOpenItem: (LibraryItem) -> Void
    let onCreate: () -> Void
    let onCreateChild: (LibraryFolder) -> Void
    let onCreateDeck: (LibraryFolder) -> Void
    let onCreateNote: (LibraryFolder) -> Void
    let onRename: (LibraryFolder) -> Void
    let onDelete: (LibraryFolder) -> Void
    let onMove: (LibraryFolder, Int) -> Void
    let onRenameItem: (LibraryItem) -> Void
    let onDuplicateItem: (LibraryItem) -> Void
    let onDeleteItem: (LibraryItem) -> Void
    let onDeleteSelection: (Set<UUID>) -> Void
    let onDropEntry: (String, LibraryFolder) -> Bool
    let onToggleFolderFavorite: (LibraryFolder) -> Void
    let onToggleItemFavorite: (LibraryItem) -> Void
    let onStyleFolder: (LibraryFolder) -> Void
    let onEditTags: (LibraryItem) -> Void
    let onShowTrash: () -> Void
    @State private var selectionAnchor: UUID?
    @State private var expandedFolderIDs: Set<UUID> = []

    private var roots: [LibraryFolder] {
        folders.filter { $0.parent == nil && $0.trashedAt == nil }.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var activeItems: [LibraryItem] { folders.flatMap(\.items).filter { $0.trashedAt == nil } }
    private var favoriteFolders: [LibraryFolder] { folders.filter { $0.trashedAt == nil && $0.favoriteAt != nil }.sorted { ($0.favoriteAt ?? .distantPast) > ($1.favoriteAt ?? .distantPast) } }
    private var favoriteItems: [LibraryItem] { activeItems.filter { $0.favoriteAt != nil }.sorted { ($0.favoriteAt ?? .distantPast) > ($1.favoriteAt ?? .distantPast) } }
    private var recentItems: [LibraryItem] {
        let byID = Dictionary(uniqueKeysWithValues: activeItems.map { ($0.id, $0) })
        let recorded = session.recentItemIDs.compactMap { byID[$0] }
        let current = selectedItemID.flatMap { byID[$0] }
        var values: [LibraryItem] = []
        for item in ([current].compactMap { $0 } + recorded) where !values.contains(where: { $0.id == item.id }) {
            values.append(item)
        }
        if !values.isEmpty { return Array(values.prefix(5)) }
        return Array(activeItems.filter { $0.lastOpenedAt != nil }.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("LIBRARY").font(.caption2.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Button { expandedFolderIDs = Set(folders.filter { $0.trashedAt == nil }.map(\.id)) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .buttonStyle(.plain).hoverFeedback(compact: true).help("Expand all")
                        Button { expandedFolderIDs.removeAll() } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                            .buttonStyle(.plain).hoverFeedback(compact: true).help("Collapse all")
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 5)

                    if !favoriteFolders.isEmpty || !favoriteItems.isEmpty {
                        sidebarLabel("FAVORITES")
                        ForEach(favoriteFolders.prefix(4)) { folder in quickFolder(folder) }
                        ForEach(favoriteItems.prefix(6)) { item in quickItem(item) }
                    }

                    if !recentItems.isEmpty {
                        sidebarLabel("RECENT")
                        ForEach(recentItems) { item in quickItem(item) }
                    }

                    if !favoriteFolders.isEmpty || !favoriteItems.isEmpty || !recentItems.isEmpty { sidebarLabel("FOLDERS") }

                    ForEach(roots) { folder in
                        FolderTreeNode(
                            folder: folder,
                            depth: 0,
                            selection: $selection,
                            selectedItemID: selectedItemID,
                            multiSelection: $multiSelection,
                            expandedFolderIDs: $expandedFolderIDs,
                            onActivateSelection: activateSelection,
                            onDeleteSelected: deleteSelected,
                            onSelect: onSelect,
                            onOpenItem: onOpenItem,
                            onCreateChild: onCreateChild,
                            onCreateDeck: onCreateDeck,
                            onCreateNote: onCreateNote,
                            onRename: onRename,
                            onDelete: onDelete,
                            onMove: onMove,
                            onRenameItem: onRenameItem,
                            onDuplicateItem: onDuplicateItem,
                            onDeleteItem: onDeleteItem,
                            onDropEntry: onDropEntry,
                            onToggleFolderFavorite: onToggleFolderFavorite,
                            onToggleItemFavorite: onToggleItemFavorite,
                            onStyleFolder: onStyleFolder,
                            onEditTags: onEditTags
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Divider()
            HStack(spacing: 6) {
                Button(action: onCreate) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverFeedback()
                .help("New top-level folder")
                .accessibilityLabel("New top-level folder")
                Button(action: onShowTrash) { Image(systemName: "trash").frame(width: 28, height: 26) }
                    .buttonStyle(.plain).hoverFeedback(compact: true).help("Trash")
            }
            .padding(12)
            .background(Color.primary.opacity(0.035))
        }
        .background(SidebarMaterialBackground())
        .navigationTitle("FlashNotes")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: folderTreeSignature)
        .onDeleteCommand {
            if !multiSelection.isEmpty { onDeleteSelection(multiSelection) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandAllFolders)) { _ in
            expandedFolderIDs = Set(folders.filter { $0.trashedAt == nil }.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .collapseAllFolders)) { _ in
            expandedFolderIDs.removeAll()
        }
        .onAppear {
            if expandedFolderIDs.isEmpty { expandedFolderIDs = Set(folders.filter { $0.trashedAt == nil }.map(\.id)) }
        }
    }

    private func sidebarLabel(_ value: String) -> some View {
        Text(value).font(.caption2.bold()).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.top, 9).padding(.bottom, 3)
    }

    private func quickFolder(_ folder: LibraryFolder) -> some View {
        Button { onSelect(folder) } label: {
            Label(folder.name, systemImage: folder.effectiveSymbolName).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverFeedback()
        .contextMenu {
            Button("Remove from Favorites", systemImage: "star.slash") { onToggleFolderFavorite(folder) }
        }
    }

    private func quickItem(_ item: LibraryItem) -> some View {
        Button { onOpenItem(item) } label: {
            Label(item.title, systemImage: item.kind == .deck ? "rectangle.stack" : "note.text").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverFeedback()
        .contextMenu {
            Button("Remove from Favorites", systemImage: "star.slash") { onToggleItemFavorite(item) }
        }
    }

    private var folderTreeSignature: [UUID] {
        func ids(_ values: [LibraryFolder]) -> [UUID] {
            values.flatMap { [$0.id] + ids($0.children) }
        }
        return ids(roots)
    }

    private var selectableIDs: [UUID] {
        func ids(_ values: [LibraryFolder]) -> [UUID] {
            values.flatMap { folder in
                [folder.id]
                    + ids(folder.children.filter { $0.trashedAt == nil }.sorted { $0.sortIndex < $1.sortIndex })
                    + sortedItems(folder.items.filter { $0.trashedAt == nil }).map(\.id)
            }
        }
        return ids(roots)
    }

    private func sortedItems(_ items: [LibraryItem]) -> [LibraryItem] {
        items.sorted {
            if $0.kind != $1.kind { return $0.kind == .note }
            return $0.sortIndex < $1.sortIndex
        }
    }

    private func activateSelection(_ id: UUID, action: () -> Void) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift),
           let anchor = selectionAnchor,
           let first = selectableIDs.firstIndex(of: anchor),
           let last = selectableIDs.firstIndex(of: id) {
            multiSelection = Set(selectableIDs[min(first, last)...max(first, last)])
            return
        }
        if modifiers.contains(.command) {
            if multiSelection.contains(id) { multiSelection.remove(id) } else { multiSelection.insert(id) }
            selectionAnchor = id
            return
        }
        multiSelection = [id]
        selectionAnchor = id
        action()
    }

    private func deleteSelected(_ id: UUID, fallback: () -> Void) {
        if multiSelection.contains(id), multiSelection.count > 1 {
            onDeleteSelection(multiSelection)
        } else {
            fallback()
        }
    }
}

private struct FolderTreeNode: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let folder: LibraryFolder
    let depth: Int
    @Binding var selection: UUID?
    let selectedItemID: UUID?
    @Binding var multiSelection: Set<UUID>
    @Binding var expandedFolderIDs: Set<UUID>
    let onActivateSelection: (UUID, () -> Void) -> Void
    let onDeleteSelected: (UUID, () -> Void) -> Void
    let onSelect: (LibraryFolder) -> Void
    let onOpenItem: (LibraryItem) -> Void
    let onCreateChild: (LibraryFolder) -> Void
    let onCreateDeck: (LibraryFolder) -> Void
    let onCreateNote: (LibraryFolder) -> Void
    let onRename: (LibraryFolder) -> Void
    let onDelete: (LibraryFolder) -> Void
    let onMove: (LibraryFolder, Int) -> Void
    let onRenameItem: (LibraryItem) -> Void
    let onDuplicateItem: (LibraryItem) -> Void
    let onDeleteItem: (LibraryItem) -> Void
    let onDropEntry: (String, LibraryFolder) -> Bool
    let onToggleFolderFavorite: (LibraryFolder) -> Void
    let onToggleItemFavorite: (LibraryItem) -> Void
    let onStyleFolder: (LibraryFolder) -> Void
    let onEditTags: (LibraryItem) -> Void
    @State private var isHovered = false
    @State private var isDropTarget = false

    private var isExpanded: Bool { expandedFolderIDs.contains(folder.id) }
    private var children: [LibraryFolder] { LibraryFeatures.sortedFolders(folder.children, for: folder) }
    private var items: [LibraryItem] {
        LibraryFeatures.sortedItems(folder.items, for: folder)
    }
    private var hasContents: Bool { !children.isEmpty || !items.isEmpty }
    private var isSelected: Bool { selection == folder.id || multiSelection.contains(folder.id) }
    private var descendantItemCount: Int {
        folder.items.filter { $0.trashedAt == nil }.count + children.reduce(0) { $0 + countItems(in: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row
            if isExpanded {
                ForEach(children) { child in
                    FolderTreeNode(
                        folder: child,
                        depth: depth + 1,
                        selection: $selection,
                        selectedItemID: selectedItemID,
                        multiSelection: $multiSelection,
                        expandedFolderIDs: $expandedFolderIDs,
                        onActivateSelection: onActivateSelection,
                        onDeleteSelected: onDeleteSelected,
                        onSelect: onSelect,
                        onOpenItem: onOpenItem,
                        onCreateChild: onCreateChild,
                        onCreateDeck: onCreateDeck,
                        onCreateNote: onCreateNote,
                        onRename: onRename,
                        onDelete: onDelete,
                        onMove: onMove,
                        onRenameItem: onRenameItem,
                        onDuplicateItem: onDuplicateItem,
                        onDeleteItem: onDeleteItem,
                        onDropEntry: onDropEntry,
                        onToggleFolderFavorite: onToggleFolderFavorite,
                        onToggleItemFavorite: onToggleItemFavorite,
                        onStyleFolder: onStyleFolder,
                        onEditTags: onEditTags
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ForEach(items) { item in
                    SidebarItemRow(
                        item: item,
                        depth: depth + 1,
                        isSelected: selectedItemID == item.id || multiSelection.contains(item.id),
                        onOpen: { onActivateSelection(item.id) { onOpenItem(item) } },
                        onRename: { onRenameItem(item) },
                        onDuplicate: { onDuplicateItem(item) },
                        onDelete: { onDeleteSelected(item.id) { onDeleteItem(item) } },
                        selectionCount: multiSelection.contains(item.id) ? multiSelection.count : 1,
                        dragPayload: "item:\(item.id.uuidString)",
                        onToggleFavorite: { onToggleItemFavorite(item) },
                        onEditTags: { onEditTags(item) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var row: some View {
        Button {
            onActivateSelection(folder.id) {
                onSelect(folder)
                guard hasContents else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    if isExpanded { expandedFolderIDs.remove(folder.id) } else { expandedFolderIDs.insert(folder.id) }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(!hasContents || !isExpanded ? .zero : .degrees(90))
                    .opacity(hasContents ? 1 : 0)
                    .frame(width: 14, height: 24)
                Image(systemName: folder.effectiveSymbolName)
                    .foregroundStyle(folder.colorHex.map { Color(libraryHex: $0) } ?? (isSelected ? Color.primary : Color.secondary))
                Text(folder.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if descendantItemCount > 0 {
                    Text("\(descendantItemCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasContents ? "\(folder.name), \(isExpanded ? "expanded" : "collapsed")" : folder.name)
        .accessibilityHint(hasContents ? "Activates the folder and toggles its contents" : "Activates the folder")
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.horizontal, 9)
        .frame(height: 36)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.68) : (isDropTarget ? Color.accentColor.opacity(0.18) : (isHovered ? Color.primary.opacity(0.065) : .clear)))
        }
        .onHover { isHovered = $0 }
        .draggable("folder:\(folder.id.uuidString)") {
            SidebarDragPreview(title: folder.name, systemImage: "folder.fill")
        }
        .dropDestination(for: String.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            return onDropEntry(payload, folder)
        } isTargeted: { isDropTarget = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button("New Subfolder", systemImage: "folder.badge.plus") { onCreateChild(folder) }
            Button("New Flashcard Deck", systemImage: "rectangle.stack.badge.plus") { onCreateDeck(folder) }
            Button("New Note", systemImage: "note.text.badge.plus") { onCreateNote(folder) }
            Divider()
            Button("Rename") { onRename(folder) }
            Button(folder.favoriteAt == nil ? "Add to Favorites" : "Remove from Favorites", systemImage: folder.favoriteAt == nil ? "star" : "star.slash") { onToggleFolderFavorite(folder) }
            Button("Change Color & Symbol…", systemImage: "paintpalette") { onStyleFolder(folder) }
            Divider()
            Button("Move Up", systemImage: "arrow.up") { onMove(folder, -1) }
            Button("Move Down", systemImage: "arrow.down") { onMove(folder, 1) }
            Divider()
            Button(multiSelection.contains(folder.id) && multiSelection.count > 1 ? "Delete Selected" : "Delete", role: .destructive) {
                onDeleteSelected(folder.id) { onDelete(folder) }
            }
        }
    }

    private func countItems(in value: LibraryFolder) -> Int {
        value.items.filter { $0.trashedAt == nil }.count + value.children.filter { $0.trashedAt == nil }.reduce(0) { $0 + countItems(in: $1) }
    }
}

private struct SidebarItemRow: View {
    let item: LibraryItem
    let depth: Int
    let isSelected: Bool
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let selectionCount: Int
    let dragPayload: String
    let onToggleFavorite: () -> Void
    let onEditTags: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 7) {
                Color.clear
                    .frame(width: 14, height: 24)
                Image(systemName: item.kind == .deck ? "rectangle.stack" : "note.text")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 16)
                Text(item.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.horizontal, 9)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : (isHovered ? Color.primary.opacity(0.06) : .clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .draggable(dragPayload) {
            SidebarDragPreview(
                title: item.title,
                systemImage: item.kind == .deck ? "rectangle.stack" : "note.text"
            )
        }
        .accessibilityLabel("\(item.kind == .deck ? "Deck" : "Note"), \(item.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Rename", action: onRename)
            Button("Duplicate", action: onDuplicate)
            Button(item.favoriteAt == nil ? "Add to Favorites" : "Remove from Favorites", systemImage: item.favoriteAt == nil ? "star" : "star.slash", action: onToggleFavorite)
            Button("Edit Tags…", systemImage: "tag", action: onEditTags)
            Divider()
            Button(selectionCount > 1 ? "Delete Selected" : "Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct SidebarDragPreview: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minWidth: 150, maxWidth: 240, minHeight: 38, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.18)))
    }
}
