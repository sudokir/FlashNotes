import SwiftUI

private struct HoverFeedbackModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    let compact: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, compact ? 5 : 7)
            .padding(.vertical, compact ? 4 : 5)
            .brightness(isHovered ? (colorScheme == .dark ? 0.09 : -0.055) : 0)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovered)
    }
}

extension View {
    func hoverFeedback(compact: Bool = false) -> some View {
        modifier(HoverFeedbackModifier(compact: compact))
    }
}
