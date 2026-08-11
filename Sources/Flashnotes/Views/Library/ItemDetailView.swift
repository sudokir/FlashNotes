import SwiftUI

struct ItemDetailView: View {
    @Bindable var item: LibraryItem
    @Binding var reviewDeck: LibraryItem?
    let noteOutlineState: NoteOutlineState

    var body: some View {
        Group {
            switch item.kind {
            case .deck:
                DeckEditorView(deck: item) { reviewDeck = item }
            case .note:
                NoteEditorView(note: item, outlineState: noteOutlineState)
            }
        }
    }
}
