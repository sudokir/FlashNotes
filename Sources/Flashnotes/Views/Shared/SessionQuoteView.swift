import SwiftUI

struct SessionQuoteView: View {
    let quote: SessionQuote

    var body: some View {
        VStack(spacing: 12) {
            OrganicGradientText(text: "“\(quote.text)”", size: 24)
            Text("— \(quote.author)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .frame(maxWidth: 720)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quote: \(quote.text), by \(quote.author)")
    }

}

struct OrganicGradientText: View {
    let text: String
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .foregroundStyle(.clear)
            .overlay {
                OrganicQuoteFill(shouldAnimate: shouldAnimate)
                    .mask(label)
            }
            .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .serif))
            .italic()
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var shouldAnimate: Bool {
        !reduceMotion && !ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }
}

/// Soft, independently moving light and shadow fields that cover the full
/// quote without exposing a rotating geometric edge through the text mask.
private struct OrganicQuoteFill: View {
    let shouldAnimate: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !shouldAnimate)) { timeline in
            GeometryReader { geometry in
                let time = shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0
                let phase = CGFloat(time * 2)
                let width = max(geometry.size.width, 1)
                let height = max(geometry.size.height, 1)

                ZStack {
                    baseColor
                    flowingBlob(
                        color: .white.opacity(colorScheme == .dark ? 0.92 : 0.76),
                        size: CGSize(width: width * 0.78, height: max(height * 3.4, 150)),
                        x: width * (0.50 + 0.38 * sin(phase * 0.19)),
                        y: height * (0.50 + 0.34 * cos(phase * 0.23))
                    )
                    flowingBlob(
                        color: .black.opacity(colorScheme == .dark ? 0.58 : 0.82),
                        size: CGSize(width: width * 0.72, height: max(height * 3.0, 140)),
                        x: width * (0.50 + 0.36 * cos(phase * 0.16 + 1.7)),
                        y: height * (0.50 + 0.32 * sin(phase * 0.21 + 0.8))
                    )
                    flowingBlob(
                        color: .white.opacity(colorScheme == .dark ? 0.55 : 0.42),
                        size: CGSize(width: width * 0.56, height: max(height * 2.5, 120)),
                        x: width * (0.50 + 0.43 * sin(phase * 0.13 + 3.2)),
                        y: height * (0.50 + 0.30 * cos(phase * 0.18 + 2.1))
                    )
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.20), .clear, Color.black.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .scaleEffect(x: 1.8, y: 3.2)
                    .rotationEffect(.degrees(8 * sin(phase * 0.12)))
                    .offset(x: width * 0.22 * sin(phase * 0.15 + 0.6))
                    .blur(radius: 18)
                }
                .frame(width: width, height: height)
                .clipped()
                .drawingGroup(opaque: false)
            }
        }
        .allowsHitTesting(false)
    }

    private var baseColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.72)
    }

    private func flowingBlob(color: Color, size: CGSize, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.45), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.5
                )
            )
            .frame(width: size.width, height: size.height)
            .position(x: x, y: y)
            .blur(radius: 24)
    }
}
