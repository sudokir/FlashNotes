import SwiftUI

struct ReviewContainerView: View {
    let deck: LibraryItem
    @Environment(\.dismiss) private var dismiss
    @State private var order: ReviewOrder = .random
    @State private var session: ReviewSession?

    private var cards: [Flashcard] { deck.cards.sorted { $0.sortIndex < $1.sortIndex } }

    var body: some View {
        Group {
            if let session {
                ReviewView(cards: cards, session: session, onSessionChange: { self.session = $0 }, onExit: { dismiss() })
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "rectangle.stack.fill").font(.system(size: 44)).foregroundStyle(.tint)
                    VStack(spacing: 6) {
                        Text(deck.title).font(.title.bold())
                        Text("\(cards.count) cards").foregroundStyle(.secondary)
                    }
                    Picker("Order", selection: $order) {
                        ForEach(ReviewOrder.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: 280)
                    HStack {
                        Button("Cancel") { dismiss() }.hoverFeedback().keyboardShortcut(.cancelAction)
                        Button("Start Review") {
                            session = ReviewSession(cardIDs: cards.map(\.id), order: order)
                        }
                        .buttonStyle(.borderedProminent).hoverFeedback().keyboardShortcut(.defaultAction)
                    }
                }
                .frame(minWidth: 720, minHeight: 520)
                .padding(40)
            }
        }
    }
}

private struct ReviewView: View {
    let cards: [Flashcard]
    let session: ReviewSession
    let onSessionChange: (ReviewSession) -> Void
    let onExit: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentCard: Flashcard? { cards.first { $0.id == session.currentCardID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Home", systemImage: "house", action: onExit).hoverFeedback().keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Text(session.progressText).font(.headline).monospacedDigit()
                Spacer()
                Button("Restart", systemImage: "arrow.counterclockwise") { mutate { $0.restart() } }
                    .hoverFeedback()
            }
            .padding(16).background(Color(nsColor: .windowBackgroundColor))

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                if session.face == .complete {
                    ReviewCompletionView(cardCount: cards.count, onHome: onExit) { mutate { $0.restart() } }
                } else if let currentCard {
                    flipCard(currentCard)
                }
                ReviewKeyCapture { key in
                    switch key {
                    case .space: mutate { $0.space() }
                    case .left: mutate { $0.previous() }
                    case .escape: onExit()
                    }
                }
                .frame(width: 1, height: 1)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private func flipCard(_ card: Flashcard) -> some View {
        let isBack = session.face == .back
        return ZStack {
            ReviewCardFace(label: "Front", markdown: card.front)
                .opacity(isBack ? 0 : 1)
                .rotation3DEffect(.degrees(isBack ? -180 : 0), axis: (x: 0, y: 1, z: 0))
            ReviewCardFace(label: "Back", markdown: card.back)
                .opacity(isBack ? 1 : 0)
                .rotation3DEffect(.degrees(isBack ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(54)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: session.face)
        .overlay(alignment: .bottom) {
            Text(isBack ? "Space: next card  •  ←: previous  •  Esc: exit" : "Space: reveal answer  •  ←: previous  •  Esc: exit")
                .font(.caption).foregroundStyle(.secondary).padding(20)
        }
    }

    private func mutate(_ action: (inout ReviewSession) -> Void) {
        var copy = session
        action(&copy)
        onSessionChange(copy)
    }
}

private struct ReviewCompletionView: View {
    let cardCount: Int
    let onHome: () -> Void
    let onRestart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationPhase = 0

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundStyle(.green)
                .scaleEffect(animationPhase == 0 ? 0.55 : (animationPhase == 1 ? 1.24 : 1))
                .rotationEffect(.degrees(animationPhase == 0 ? -35 : (animationPhase == 1 ? 20 : 360)))
            Text("Review complete").font(.largeTitle.bold())
            Text("You reviewed all \(cardCount) cards.").foregroundStyle(.secondary)
            HStack {
                Button("Home", systemImage: "house", action: onHome)
                    .hoverFeedback()
                Button("Review Again", systemImage: "arrow.counterclockwise", action: onRestart)
                    .buttonStyle(.borderedProminent)
                    .hoverFeedback()
            }
        }
        .onAppear {
            if reduceMotion {
                animationPhase = 2
            } else {
                withAnimation(.spring(duration: 0.62, bounce: 0.5)) { animationPhase = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
                    withAnimation(.spring(duration: 0.58, bounce: 0.38)) { animationPhase = 2 }
                }
            }
        }
    }
}

private struct ReviewCardFace: View {
    @Environment(Preferences.self) private var preferences
    let label: String
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(label.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
            MarkdownTextView(
                text: .constant(markdown.isEmpty ? "No content" : markdown),
                configuration: .review,
                highlightHex: preferences.highlightHex,
                headingColors: preferences.headingColors,
                onHeadingsChange: nil
            )
        }
        .padding(24)
        .frame(maxWidth: 820, maxHeight: 520)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .glassOutline(cornerRadius: 14)
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(markdown)")
    }
}

private enum ReviewKey { case space, left, escape }

private struct ReviewKeyCapture: NSViewRepresentable {
    let onKey: (ReviewKey) -> Void
    func makeNSView(context: Context) -> KeyView { KeyView(onKey: onKey) }
    func updateNSView(_ nsView: KeyView, context: Context) { nsView.onKey = onKey; nsView.claimFocus() }

    final class KeyView: NSView {
        var onKey: (ReviewKey) -> Void
        init(onKey: @escaping (ReviewKey) -> Void) { self.onKey = onKey; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); claimFocus() }
        func claimFocus() { DispatchQueue.main.async { [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self) } }
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49: onKey(.space)
            case 123: onKey(.left)
            case 53: onKey(.escape)
            default: super.keyDown(with: event)
            }
        }
    }
}
