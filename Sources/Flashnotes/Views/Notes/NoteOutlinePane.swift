import SwiftUI

@MainActor
@Observable
final class NoteOutlineState {
    var headings: [MarkdownHeading] = []
    let controller = MarkdownEditorController()
}

struct NoteOutlinePane: View {
    let state: NoteOutlineState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Outline", systemImage: "list.bullet.indent")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 42)
            Divider()

            if state.headings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No headings yet")
                        .font(.headline)
                    Text("Add headings with # to build your outline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { state.controller.focus() }
                .help("Click to focus the note editor")
            } else {
                List {
                    NoteOutlineRows(headings: state.headings) { heading in
                        state.controller.scroll(to: heading.range)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(SidebarMaterialBackground())
    }
}

private struct NoteOutlineRows: View {
    let headings: [MarkdownHeading]
    let onSelect: (MarkdownHeading) -> Void

    var body: some View {
        ForEach(headings) { heading in
            if heading.children.isEmpty {
                row(heading)
            } else {
                DisclosureGroup {
                    NoteOutlineRows(headings: heading.children, onSelect: onSelect)
                } label: {
                    row(heading)
                }
            }
        }
    }

    private func row(_ heading: MarkdownHeading) -> some View {
        Button { onSelect(heading) } label: {
            HStack(spacing: 7) {
                Text("H\(heading.level)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(heading.title).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .hoverFeedback()
        .accessibilityLabel("Heading level \(heading.level), \(heading.title)")
    }
}

struct SidebarVerticalSplit<Upper: View, Lower: View>: View {
    @ViewBuilder let upper: () -> Upper
    @ViewBuilder let lower: () -> Lower
    @State private var upperFraction = 0.56

    var body: some View {
        GeometryReader { geometry in
            let handleHeight: CGFloat = 16
            let usableHeight = max(1, geometry.size.height - handleHeight)

            VStack(spacing: 0) {
                upper()
                    .frame(height: usableHeight * upperFraction)
                    .clipped()

                divider(usableHeight: usableHeight, totalHeight: geometry.size.height)
                    .frame(height: handleHeight)

                lower()
                    .frame(height: usableHeight * (1 - upperFraction))
                    .clipped()
            }
            .transaction { $0.disablesAnimations = true }
            .coordinateSpace(name: "sidebarSplit")
        }
    }

    private func divider(usableHeight: CGFloat, totalHeight: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                .overlay(Capsule().stroke(Color(nsColor: .separatorColor)))
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("sidebarSplit"))
                .onChanged { value in
                    let proposed = value.location.y / max(1, totalHeight)
                    upperFraction = min(0.78, max(0.25, proposed))
                }
        )
        .help("Drag to resize Library and Outline")
        .accessibilityLabel("Resize Library and Outline")
    }
}
