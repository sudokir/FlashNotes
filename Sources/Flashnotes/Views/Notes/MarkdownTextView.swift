import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MarkdownEditorConfiguration {
    case note
    case card
    case review
}

@MainActor
@Observable
final class MarkdownEditorController {
    weak var textView: NSTextView?

    func wrapSelection(prefix: String, suffix: String? = nil, placeholder: String) {
        guard let textView else { return }
        let suffix = suffix ?? prefix
        let range = textView.selectedRange()
        let selected = range.length > 0 ? (textView.string as NSString).substring(with: range) : placeholder
        let replacement = prefix + selected + suffix
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textView.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: range.location + prefix.utf16.count, length: selected.utf16.count))
    }

    func prefixLines(_ prefix: String) {
        guard let textView else { return }
        let string = textView.string as NSString
        let range = string.lineRange(for: textView.selectedRange())
        let lines = string.substring(with: range).split(separator: "\n", omittingEmptySubsequences: false)
        let replacement = lines.map { prefix + $0 }.joined(separator: "\n")
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textView.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: range.location, length: replacement.utf16.count))
    }

    func heading(level: Int) { prefixLines(String(repeating: "#", count: level) + " ") }
    func bold() { wrapSelection(prefix: "**", placeholder: "bold text") }
    func italic() { wrapSelection(prefix: "*", placeholder: "italic text") }
    func inlineCode() { wrapSelection(prefix: "`", placeholder: "code") }
    func link() { wrapSelection(prefix: "[", suffix: "](https://example.com)", placeholder: "link text") }
    func highlight() { wrapSelection(prefix: "==", placeholder: "highlighted text") }
    func color(_ hex: String) { wrapSelection(prefix: "<span style=\"color:\(hex)\">", suffix: "</span>", placeholder: "colored text") }

    func scroll(to range: NSRange) {
        guard let textView else { return }
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
        textView.setSelectedRange(NSRange(location: range.location, length: 0))
        textView.window?.makeFirstResponder(textView)
    }

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let configuration: MarkdownEditorConfiguration
    var controller: MarkdownEditorController? = nil
    var highlightHex: String = "#FFD60A"
    var headingColors: [String] = Preferences.defaultHeadingColors
    var onHeadingsChange: (([MarkdownHeading]) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = AttachmentTextView()
        textView.attachmentStore = AttachmentStore()
        textView.isRichText = true
        textView.isEditable = configuration != .review
        textView.isSelectable = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.usesFindBar = true
        textView.usesFontPanel = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 1)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainerInset = NSSize(width: configuration == .note ? 26 : 18, height: 22)
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.registerForDraggedTypes([.fileURL, .tiff, .png])

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = textView
        let contentSize = scroll.contentSize
        textView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: max(contentSize.height, 1))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        context.coordinator.textView = textView
        controller?.textView = textView
        context.coordinator.display(markdown: text, preservingSelection: false)
        context.coordinator.applyStyles()
        context.coordinator.scheduleHeadings()
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        controller?.textView = textView
        if context.coordinator.markdown(from: textView) != text {
            context.coordinator.display(markdown: text, preservingSelection: true)
            context.coordinator.applyStyles()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?
        private var headingWorkItem: DispatchWorkItem?
        private var applyingStyles = false

        init(parent: MarkdownTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !applyingStyles, let textView else { return }
            convertVisibleImageReferences(in: textView)
            convertCompletedMath(in: textView)
            parent.text = markdown(from: textView)
            applyStyles()
            scheduleHeadings()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            applyStyles()
        }

        func textDidBeginEditing(_ notification: Notification) {
            applyStyles()
        }

        func textDidEndEditing(_ notification: Notification) {
            applyStyles()
        }

        func markdown(from textView: NSTextView) -> String {
            guard let storage = textView.textStorage else { return textView.string }
            var result = ""
            var location = 0
            while location < storage.length {
                if let math = storage.attribute(.attachment, at: location, effectiveRange: nil) as? MathTextAttachment {
                    result += "$$\(math.expression)$$"
                    location += 1
                } else if let attachment = storage.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment,
                   let name = attachment.fileWrapper?.preferredFilename ?? attachment.fileWrapper?.filename {
                    let width = max(1, Int(attachment.bounds.width.rounded()))
                    result += "![Image](\(AttachmentStore.reference(for: name))){width=\(width)}"
                    location += 1
                } else {
                    result += (storage.string as NSString).substring(with: NSRange(location: location, length: 1))
                    location += 1
                }
            }
            return result
        }

        func display(markdown: String, preservingSelection: Bool) {
            guard let textView, let storage = textView.textStorage else { return }
            let previous = textView.selectedRange()
            let rendered = NSMutableAttributedString(string: markdown)
            replaceImageReferences(in: rendered)
            replaceMathReferences(in: rendered)
            applyingStyles = true
            storage.setAttributedString(rendered)
            applyingStyles = false
            if preservingSelection {
                textView.setSelectedRange(NSRange(location: min(previous.location, storage.length), length: 0))
            }
        }

        func scheduleHeadings() {
            headingWorkItem?.cancel()
            guard parent.onHeadingsChange != nil, let textView else { return }
            let value = textView.string
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.parent.onHeadingsChange?(HeadingParser.hierarchy(in: value))
            }
            headingWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }

        func applyStyles() {
            guard let textView, let storage = textView.textStorage else { return }
            applyingStyles = true
            defer { applyingStyles = false }
            let string = storage.string
            let full = NSRange(location: 0, length: storage.length)
            var attachments: [(NSRange, NSTextAttachment)] = []
            storage.enumerateAttribute(.attachment, in: full) { value, range, _ in
                if let attachment = value as? NSTextAttachment { attachments.append((range, attachment)) }
            }
            let baseSize: CGFloat = switch parent.configuration {
            case .note: 15
            case .card: 17
            case .review: 24
            }
            storage.beginEditing()
            storage.setAttributes([
                .font: NSFont.systemFont(ofSize: baseSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(spacing: 5)
            ], range: full)
            for (range, attachment) in attachments {
                storage.addAttribute(.attachment, value: attachment, range: range)
            }
            styleHeadings(storage: storage, string: string, baseSize: baseSize)
            style(pattern: #"\*\*(.+?)\*\*"#, in: storage, string: string, attributes: [.font: NSFont.boldSystemFont(ofSize: baseSize)])
            style(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, in: storage, string: string, attributes: [.font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: baseSize), toHaveTrait: .italicFontMask)])
            style(pattern: #"`([^`\n]+)`"#, in: storage, string: string, attributes: [.font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular), .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.16)])
            style(pattern: #"(?s)```.*?```"#, in: storage, string: string, attributes: [.font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular), .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.18)])
            style(pattern: #"(?m)\$\$[^$\n]*$"#, in: storage, string: string, attributes: [.font: NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular), .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.12)])
            let highlight = (NSColor(hex: parent.highlightHex) ?? .systemYellow).withAlphaComponent(0.35)
            style(pattern: #"==(.+?)=="#, in: storage, string: string, attributes: [.backgroundColor: highlight])
            style(pattern: #"(?m)^> .+$"#, in: storage, string: string, attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: baseSize), toHaveTrait: .italicFontMask)])
            style(pattern: #"\[[^]]+\]\([^)]+\)"#, in: storage, string: string, attributes: [.foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue])
            styleColorSpans(storage: storage, string: string)
            hideMarkdownSyntax(storage: storage, string: string)
            storage.endEditing()
        }

        private func hideMarkdownSyntax(storage: NSTextStorage, string: String) {
            let hidden: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 0.01),
                .foregroundColor: NSColor.clear,
                .kern: -0.01
            ]

            let revealedRange = activeLineRange(in: string)
            hideMatches(pattern: #"(?m)^(#{1,6})[ \t]+"#, groups: [0], storage: storage, string: string, attributes: hidden, revealedRange: revealedRange)
            hidePairedMarkers(pattern: #"\*\*([^*\n]+)\*\*"#, markerLength: 2, storage: storage, string: string, attributes: hidden, revealedRange: revealedRange)
            hidePairedMarkers(pattern: #"==([^=\n]+)=="#, markerLength: 2, storage: storage, string: string, attributes: hidden, revealedRange: revealedRange)
            hidePairedMarkers(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, markerLength: 1, storage: storage, string: string, attributes: hidden, revealedRange: revealedRange)
            hidePairedMarkers(pattern: #"`([^`\n]+)`"#, markerLength: 1, storage: storage, string: string, attributes: hidden, revealedRange: revealedRange)

            let linkPattern = #"\[([^]]+)\]\(([^)]+)\)"#
            guard let linkRegex = try? NSRegularExpression(pattern: linkPattern) else { return }
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in linkRegex.matches(in: string, range: full) {
                let titleRange = match.range(at: 1)
                let prefix = NSRange(location: match.range.location, length: max(0, titleRange.location - match.range.location))
                let suffixStart = NSMaxRange(titleRange)
                let suffix = NSRange(location: suffixStart, length: max(0, NSMaxRange(match.range) - suffixStart))
                if !intersects(prefix, revealedRange), NSMaxRange(prefix) <= storage.length { storage.addAttributes(hidden, range: prefix) }
                if !intersects(suffix, revealedRange), NSMaxRange(suffix) <= storage.length { storage.addAttributes(hidden, range: suffix) }
            }

            let colorPattern = #"<span style=\"color:#[0-9A-Fa-f]{6}\">(.*?)</span>"#
            guard let colorRegex = try? NSRegularExpression(pattern: colorPattern) else { return }
            for match in colorRegex.matches(in: string, range: full) {
                let content = match.range(at: 1)
                let prefix = NSRange(location: match.range.location, length: content.location - match.range.location)
                let suffix = NSRange(location: NSMaxRange(content), length: NSMaxRange(match.range) - NSMaxRange(content))
                if !intersects(prefix, revealedRange), NSMaxRange(prefix) <= storage.length { storage.addAttributes(hidden, range: prefix) }
                if !intersects(suffix, revealedRange), NSMaxRange(suffix) <= storage.length { storage.addAttributes(hidden, range: suffix) }
            }
        }

        private func activeLineRange(in string: String) -> NSRange? {
            guard let textView,
                  textView.isEditable,
                  textView.window?.firstResponder === textView else { return nil }
            let nsString = string as NSString
            let selection = textView.selectedRange()
            let location = min(selection.location, nsString.length)
            let safeRange = NSRange(location: location, length: min(selection.length, nsString.length - location))
            return nsString.lineRange(for: safeRange)
        }

        private func intersects(_ range: NSRange, _ other: NSRange?) -> Bool {
            guard let other else { return false }
            return NSIntersectionRange(range, other).length > 0 || (range.length == 0 && NSLocationInRange(range.location, other))
        }

        private func hideMatches(
            pattern: String,
            groups: [Int],
            storage: NSTextStorage,
            string: String,
            attributes: [NSAttributedString.Key: Any],
            revealedRange: NSRange?
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: full) {
                for group in groups {
                    let range = match.range(at: group)
                    if range.location != NSNotFound, !intersects(range, revealedRange), NSMaxRange(range) <= storage.length {
                        storage.addAttributes(attributes, range: range)
                    }
                }
            }
        }

        private func hidePairedMarkers(
            pattern: String,
            markerLength: Int,
            storage: NSTextStorage,
            string: String,
            attributes: [NSAttributedString.Key: Any],
            revealedRange: NSRange?
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: full) {
                let opening = NSRange(location: match.range.location, length: markerLength)
                let closing = NSRange(location: NSMaxRange(match.range) - markerLength, length: markerLength)
                if !intersects(opening, revealedRange), NSMaxRange(opening) <= storage.length { storage.addAttributes(attributes, range: opening) }
                if !intersects(closing, revealedRange), NSMaxRange(closing) <= storage.length { storage.addAttributes(attributes, range: closing) }
            }
        }

        private func replaceImageReferences(in attributed: NSMutableAttributedString) {
            let pattern = #"!\[[^]]*\]\((attachment://[A-Za-z0-9._-]+)\)(?:\{width=([0-9]+(?:\.[0-9]+)?)\})?"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let string = attributed.string
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: full).reversed() {
                let reference = (string as NSString).substring(with: match.range(at: 1))
                guard let attachment = imageAttachment(for: reference, maxWidth: 900, requestedWidth: imageWidth(from: match, in: string)) else { continue }
                attributed.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
            }
        }

        private func convertVisibleImageReferences(in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let originalSelection = textView.selectedRange()
            let pattern = #"!\[[^]]*\]\((attachment://[A-Za-z0-9._-]+)\)(?:\{width=([0-9]+(?:\.[0-9]+)?)\})?"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let string = storage.string
            let full = NSRange(location: 0, length: (string as NSString).length)
            let matches = regex.matches(in: string, range: full)
            guard !matches.isEmpty else { return }
            applyingStyles = true
            var newLocation = originalSelection.location
            for match in matches.reversed() {
                let reference = (string as NSString).substring(with: match.range(at: 1))
                guard let attachment = imageAttachment(for: reference, maxWidth: 900, requestedWidth: imageWidth(from: match, in: string)) else { continue }
                storage.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
                if match.range.location < originalSelection.location {
                    newLocation -= max(0, match.range.length - 1)
                }
            }
            applyingStyles = false
            textView.setSelectedRange(NSRange(location: max(0, min(newLocation, storage.length)), length: 0))
        }

        private func replaceMathReferences(in attributed: NSMutableAttributedString) {
            let pattern = #"\$\$(.+?)\$\$"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let string = attributed.string
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: full).reversed() {
                let expression = (string as NSString).substring(with: match.range(at: 1))
                attributed.replaceCharacters(in: match.range, with: NSAttributedString(attachment: mathAttachment(for: expression, maxWidth: 900)))
            }
        }

        private func convertCompletedMath(in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let originalSelection = textView.selectedRange()
            let pattern = #"\$\$(.+?)\$\$"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let string = storage.string
            let full = NSRange(location: 0, length: (string as NSString).length)
            let matches = regex.matches(in: string, range: full)
            guard !matches.isEmpty else { return }
            applyingStyles = true
            var newLocation = originalSelection.location
            for match in matches.reversed() {
                let expression = (string as NSString).substring(with: match.range(at: 1))
                storage.replaceCharacters(in: match.range, with: NSAttributedString(attachment: mathAttachment(for: expression, maxWidth: 900)))
                if match.range.location < originalSelection.location {
                    newLocation -= max(0, match.range.length - 1)
                }
            }
            applyingStyles = false
            textView.setSelectedRange(NSRange(location: max(0, min(newLocation, storage.length)), length: 0))
        }

        private func imageWidth(from match: NSTextCheckingResult, in string: String) -> CGFloat? {
            guard match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound else { return nil }
            return Double((string as NSString).substring(with: match.range(at: 2))).map(CGFloat.init)
        }

        private func styleHeadings(storage: NSTextStorage, string: String, baseSize: CGFloat) {
            let colors = parent.headingColors.map { NSColor(hex: $0) ?? .labelColor }
            for heading in HeadingParser.flatHeadings(in: string) where NSMaxRange(heading.range) <= storage.length {
                let size = max(baseSize + 2, baseSize + CGFloat(7 - heading.level) * 2.2)
                storage.addAttributes([
                    .font: NSFont.systemFont(ofSize: size, weight: heading.level <= 2 ? .bold : .semibold),
                    .foregroundColor: colors[min(heading.level - 1, max(0, colors.count - 1))],
                    .paragraphStyle: paragraphStyle(spacing: 8)
                ], range: heading.range)
            }
        }

        private func style(pattern: String, in storage: NSTextStorage, string: String, attributes: [NSAttributedString.Key: Any]) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: range) where NSMaxRange(match.range) <= storage.length {
                storage.addAttributes(attributes, range: match.range)
            }
        }

        private func styleColorSpans(storage: NSTextStorage, string: String) {
            let pattern = #"<span style="color:(#[0-9A-Fa-f]{6})">(.*?)</span>"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let full = NSRange(location: 0, length: (string as NSString).length)
            for match in regex.matches(in: string, range: full) where NSMaxRange(match.range) <= storage.length {
                let hex = (string as NSString).substring(with: match.range(at: 1))
                if let color = NSColor(hex: hex) { storage.addAttribute(.foregroundColor, value: color, range: match.range) }
            }
        }

        private func paragraphStyle(spacing: CGFloat) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 2
            style.paragraphSpacing = spacing
            return style
        }
    }
}

private final class AttachmentTextView: NSTextView {
    var attachmentStore = AttachmentStore()
    private var resizingAttachment: ResizableImageAttachment?
    private var resizingRange: NSRange?
    private var dragStartPoint: NSPoint = .zero
    private var dragStartWidth: CGFloat = 0

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if selectedRange().length == 1,
           let selected = imageAttachmentInfo(atCharacterIndex: selectedRange().location),
           resizeHandle(for: selected.rect).insetBy(dx: -7, dy: -7).contains(point) {
            beginResizing(selected, at: point)
            return
        }
        if let info = attachmentInfo(at: point), let math = info.attachment as? MathTextAttachment {
            let source = "$$\(math.expression)"
            guard shouldChangeText(in: info.range, replacementString: source) else { return }
            textStorage?.replaceCharacters(in: info.range, with: source)
            didChangeText()
            setSelectedRange(NSRange(location: info.range.location + source.utf16.count, length: 0))
            return
        }
        if let info = imageAttachmentInfo(at: point) {
            setSelectedRange(info.range)
            needsDisplay = true
            if resizeHandle(for: info.rect).insetBy(dx: -7, dy: -7).contains(point) {
                beginResizing(info, at: point)
                return
            }
            return
        }
        super.mouseDown(with: event)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let attachment = resizingAttachment, let range = resizingRange else {
            super.mouseDragged(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let availableWidth = max(120, visibleRect.width - textContainerInset.width * 2)
        let width = min(900, availableWidth, max(80, dragStartWidth + point.x - dragStartPoint.x))
        attachment.bounds = NSRect(x: 0, y: -4, width: width, height: width / max(attachment.aspectRatio, 0.01))
        layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager?.invalidateDisplay(forCharacterRange: range)
        didChangeText()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if resizingAttachment != nil {
            resizingAttachment = nil
            resizingRange = nil
            needsDisplay = true
            return
        }
        super.mouseUp(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let selection = selectedRange()
        guard selection.length == 1,
              let info = imageAttachmentInfo(atCharacterIndex: selection.location) else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: resizeHandle(for: info.rect), xRadius: 2, yRadius: 2).fill()
        NSColor.windowBackgroundColor.setStroke()
        let border = NSBezierPath(roundedRect: resizeHandle(for: info.rect), xRadius: 2, yRadius: 2)
        border.lineWidth = 1
        border.stroke()
    }

    private func beginResizing(_ info: (attachment: ResizableImageAttachment, range: NSRange, rect: NSRect), at point: NSPoint) {
        resizingAttachment = info.attachment
        resizingRange = info.range
        dragStartPoint = point
        dragStartWidth = info.attachment.bounds.width
    }

    private func attachmentInfo(at point: NSPoint) -> (attachment: NSTextAttachment, range: NSRange, rect: NSRect)? {
        guard let storage = textStorage, storage.length > 0 else { return nil }
        var result: (NSTextAttachment, NSRange, NSRect)?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            guard let attachment = value as? NSTextAttachment,
                  let rect = self.attachmentRect(atCharacterIndex: range.location),
                  rect.insetBy(dx: -3, dy: -3).contains(point) else { return }
            result = (attachment, range, rect)
            stop.pointee = true
        }
        return result
    }

    private func imageAttachmentInfo(at point: NSPoint) -> (attachment: ResizableImageAttachment, range: NSRange, rect: NSRect)? {
        guard let info = attachmentInfo(at: point), let image = info.attachment as? ResizableImageAttachment else { return nil }
        return (image, info.range, info.rect)
    }

    private func imageAttachmentInfo(atCharacterIndex index: Int) -> (attachment: ResizableImageAttachment, range: NSRange, rect: NSRect)? {
        guard let storage = textStorage, index >= 0, index < storage.length,
              let attachment = storage.attribute(.attachment, at: index, effectiveRange: nil) as? ResizableImageAttachment,
              let rect = attachmentRect(atCharacterIndex: index) else { return nil }
        return (attachment, NSRange(location: index, length: 1), rect)
    }

    private func attachmentRect(atCharacterIndex index: Int) -> NSRect? {
        guard let storage = textStorage, let layoutManager, let textContainer,
              index >= 0, index < storage.length,
              storage.attribute(.attachment, at: index, effectiveRange: nil) is NSTextAttachment else { return nil }
        let range = NSRange(location: index, length: 1)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    private func resizeHandle(for rect: NSRect) -> NSRect {
        NSRect(x: rect.maxX - 11, y: rect.maxY - 11, width: 10, height: 10)
    }

    override func paste(_ sender: Any?) {
        if insertImage(from: NSPasteboard.general) { return }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canReadImage(sender.draggingPasteboard) ? .copy : super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        insertImage(from: sender.draggingPasteboard) || super.performDragOperation(sender)
    }

    private func canReadImage(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSImage.self, NSURL.self], options: nil)
    }

    private func insertImage(from pasteboard: NSPasteboard) -> Bool {
        var data: Data?
        if let image = NSImage(pasteboard: pasteboard) { data = image.tiffRepresentation }
        if data == nil,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first,
           UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
            data = try? Data(contentsOf: url)
        }
        guard let data, let reference = try? attachmentStore.saveImage(data: data) else { return false }
        guard let attachment = imageAttachment(for: reference, maxWidth: 900, requestedWidth: nil) else { return false }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: "\u{FFFC}") else { return false }
        textStorage?.replaceCharacters(in: range, with: NSAttributedString(attachment: attachment))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + 1, length: 0))
        return true
    }
}

private func imageAttachment(for reference: String, maxWidth: CGFloat, requestedWidth: CGFloat?) -> NSTextAttachment? {
    let store = AttachmentStore()
    guard let name = AttachmentStore.filename(from: reference),
          let url = store.url(for: reference),
          let data = try? Data(contentsOf: url),
          let image = NSImage(data: data) else { return nil }
    let defaultLimit = min(520, maxWidth)
    let defaultWidth = image.size.width * min(1, defaultLimit / max(image.size.width, 1))
    let width = min(maxWidth, max(80, requestedWidth ?? defaultWidth))
    let attachment = ResizableImageAttachment()
    attachment.aspectRatio = max(image.size.width, 1) / max(image.size.height, 1)
    attachment.image = image
    attachment.bounds = NSRect(x: 0, y: -4, width: width, height: width / attachment.aspectRatio)
    let wrapper = FileWrapper(regularFileWithContents: data)
    wrapper.preferredFilename = name
    attachment.fileWrapper = wrapper
    return attachment
}

private final class ResizableImageAttachment: NSTextAttachment {
    var aspectRatio: CGFloat = 1
}

private final class MathTextAttachment: NSTextAttachment {
    let expression: String

    init(expression: String) {
        self.expression = expression
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { nil }
}

private func mathAttachment(for expression: String, maxWidth: CGFloat) -> NSTextAttachment {
    let attachment = MathTextAttachment(expression: expression)
    let display = MathRenderer.displayString(for: expression)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "STIX Two Math", size: 22) ?? NSFont(name: "Times New Roman", size: 22) ?? NSFont.systemFont(ofSize: 22),
        .foregroundColor: NSColor.labelColor
    ]
    let attributed = NSAttributedString(string: display, attributes: attributes)
    var size = attributed.size()
    size.width += 16
    size.height += 8
    let scale = min(1, maxWidth / max(size.width, 1))
    size = NSSize(width: size.width * scale, height: size.height * scale)
    let image = NSImage(size: size, flipped: false) { rect in
        NSGraphicsContext.current?.imageInterpolation = .high
        attributed.draw(in: NSRect(x: 8 * scale, y: 4 * scale, width: max(1, rect.width - 16 * scale), height: max(1, rect.height - 8 * scale)))
        return true
    }
    image.accessibilityDescription = "Mathematical expression: \(expression)"
    attachment.image = image
    attachment.bounds = NSRect(x: 0, y: -4, width: size.width, height: size.height)
    return attachment
}

enum MathRenderer {
    static func displayString(for source: String) -> String {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbols = [
            "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ", "\\theta": "θ",
            "\\lambda": "λ", "\\mu": "μ", "\\pi": "π", "\\rho": "ρ", "\\sigma": "σ",
            "\\phi": "φ", "\\omega": "ω", "\\Delta": "Δ", "\\Sigma": "Σ", "\\Omega": "Ω",
            "\\times": "×", "\\cdot": "·", "\\pm": "±", "\\leq": "≤", "\\geq": "≥",
            "\\neq": "≠", "\\approx": "≈", "\\infty": "∞", "\\sum": "∑", "\\int": "∫",
            "\\rightarrow": "→", "\\leftarrow": "←", "\\left": "", "\\right": ""
        ]
        for (command, symbol) in symbols { value = value.replacingOccurrences(of: command, with: symbol) }
        value = replacing(pattern: #"\\frac\{([^{}]+)\}\{([^{}]+)\}"#, in: value) { "\($0[1])⁄\($0[2])" }
        value = replacing(pattern: #"\\sqrt\{([^{}]+)\}"#, in: value) { "√(\($0[1]))" }
        value = replaceScripts(in: value, marker: "^", map: superscripts)
        value = replaceScripts(in: value, marker: "_", map: subscripts)
        return value
    }

    private static let superscripts: [Character: Character] = [
        "0":"⁰", "1":"¹", "2":"²", "3":"³", "4":"⁴", "5":"⁵", "6":"⁶", "7":"⁷", "8":"⁸", "9":"⁹",
        "+":"⁺", "-":"⁻", "=":"⁼", "(":"⁽", ")":"⁾", "n":"ⁿ", "i":"ⁱ"
    ]
    private static let subscripts: [Character: Character] = [
        "0":"₀", "1":"₁", "2":"₂", "3":"₃", "4":"₄", "5":"₅", "6":"₆", "7":"₇", "8":"₈", "9":"₉",
        "+":"₊", "-":"₋", "=":"₌", "(":"₍", ")":"₎", "a":"ₐ", "e":"ₑ", "i":"ᵢ", "o":"ₒ", "r":"ᵣ", "u":"ᵤ", "x":"ₓ"
    ]

    private static func replaceScripts(in source: String, marker: Character, map: [Character: Character]) -> String {
        var output = ""
        var index = source.startIndex
        while index < source.endIndex {
            guard source[index] == marker else {
                output.append(source[index]); index = source.index(after: index); continue
            }
            let next = source.index(after: index)
            guard next < source.endIndex else { output.append(marker); break }
            if source[next] == "{", let close = source[next...].firstIndex(of: "}") {
                let contents = source[source.index(after: next)..<close]
                let converted = contents.map { map[$0] ?? $0 }
                output.append(contents.allSatisfy { map[$0] != nil } ? String(converted) : "\(marker){\(contents)}")
                index = source.index(after: close)
            } else {
                output.append(map[source[next]] ?? source[next])
                index = source.index(after: next)
            }
        }
        return output
    }

    private static func replacing(pattern: String, in source: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        var value = source
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: (value as NSString).length))
        for match in matches.reversed() {
            let nsValue = value as NSString
            let groups = (0..<match.numberOfRanges).map { nsValue.substring(with: match.range(at: $0)) }
            value = nsValue.replacingCharacters(in: match.range, with: transform(groups))
        }
        return value
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((number >> 16) & 0xff) / 255, green: CGFloat((number >> 8) & 0xff) / 255, blue: CGFloat(number & 0xff) / 255, alpha: 1)
    }
}
