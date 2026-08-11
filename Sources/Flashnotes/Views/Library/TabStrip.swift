import SwiftUI

struct TabStrip: View {
    let items: [LibraryItem]
    @Binding var selectedID: UUID?
    let onClose: (UUID) -> Void

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(items) { item in
                        HStack(spacing: 7) {
                            Button {
                                selectedID = item.id
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: item.kind == .deck ? "rectangle.stack" : "note.text")
                                    Text(item.title).lineLimit(1)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])

                            TabCloseButton(title: item.title) { onClose(item.id) }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(selectedID == item.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .hoverFeedback(compact: true)
                        .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
            }
            .background(SidebarMaterialBackground())
        }
    }
}

private struct TabCloseButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 21, height: 21)
                .background(isHovered ? Color.primary.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Close \(title)")
    }
}
