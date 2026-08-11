import SwiftUI

private struct GlassOutlineModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// A thin, even edge that stays visible around the complete panel.
    func glassOutline(cornerRadius: CGFloat) -> some View {
        modifier(GlassOutlineModifier(cornerRadius: cornerRadius))
    }
}
