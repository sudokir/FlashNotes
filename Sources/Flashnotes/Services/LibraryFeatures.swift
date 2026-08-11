import AppKit
import CoreText
import Foundation

enum LibraryFeatures {
    static func sortedItems(_ items: [LibraryItem], for folder: LibraryFolder) -> [LibraryItem] {
        let active = items.filter { $0.trashedAt == nil }
        let ascending = folder.sortAscending
        return active.sorted { lhs, rhs in
            let result: ComparisonResult
            switch folder.sortMode {
            case .manual:
                if lhs.kind != rhs.kind { return lhs.kind == .note }
                result = lhs.sortIndex == rhs.sortIndex ? .orderedSame : (lhs.sortIndex < rhs.sortIndex ? .orderedAscending : .orderedDescending)
            case .title:
                result = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            case .created:
                result = lhs.createdAt.compare(rhs.createdAt)
            case .modified:
                result = lhs.modifiedAt.compare(rhs.modifiedAt)
            }
            if result == .orderedSame { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    static func sortedFolders(_ folders: [LibraryFolder], for parent: LibraryFolder? = nil) -> [LibraryFolder] {
        let active = folders.filter { $0.trashedAt == nil }
        guard let parent, parent.sortMode != .manual else { return active.sorted { $0.sortIndex < $1.sortIndex } }
        let ascending = parent.sortAscending
        return active.sorted { lhs, rhs in
            let result: ComparisonResult = switch parent.sortMode {
            case .title: lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .created: lhs.createdAt.compare(rhs.createdAt)
            case .modified: (lhs.modifiedAt ?? lhs.createdAt).compare(rhs.modifiedAt ?? rhs.createdAt)
            case .manual: lhs.sortIndex < rhs.sortIndex ? .orderedAscending : .orderedDescending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    static func searchText(for item: LibraryItem) -> String {
        ([item.title, item.noteMarkdown] + item.tags + item.cards.flatMap { [$0.front, $0.back] }).joined(separator: "\n")
    }

    static func noteStatistics(_ markdown: String) -> NoteStatistics {
        let plain = plainText(from: markdown)
        let words = plain.split { $0.isWhitespace || $0.isPunctuation }.count
        return NoteStatistics(words: words, characters: markdown.count, readingMinutes: max(1, Int(ceil(Double(words) / 220.0))))
    }

    static func plainText(from markdown: String) -> String {
        var value = markdown
        let patterns = [
            #"!\[[^\]]*\]\([^\)]*\)(?:\{width=\d+\})?"#,
            #"\[([^\]]+)\]\([^\)]+\)"#,
            #"<span\s+style=\"color:#[0-9A-Fa-f]{6}\">(.*?)</span>"#,
            #"^(#{1,6}|>|[-+*]|\d+\.)\s+"#,
            #"(\*\*|__|\*|_|==|`{1,3})"#
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: index == 3 ? .anchorsMatchLines : []) else { continue }
            let template = index == 0 ? "[Image]" : (index == 1 || index == 2 ? "$1" : "")
            value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: template)
        }
        return value
    }
}

struct NoteStatistics: Equatable {
    let words: Int
    let characters: Int
    let readingMinutes: Int
}

struct AutoCardCandidate: Equatable {
    let front: String
    let back: String
    var signature: String {
        Data((front + "\u{1F}" + back).utf8).base64EncodedString()
    }
}

enum AutoCardParser {
    static func candidates(in text: String) -> [AutoCardCandidate] {
        text.components(separatedBy: .newlines).compactMap { line in
            guard let divider = line.range(of: "::") else { return nil }
            let front = String(line[..<divider.lowerBound]).trimmingCharacters(in: .whitespaces)
            let back = String(line[divider.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !front.isEmpty, !back.isEmpty else { return nil }
            return AutoCardCandidate(front: front, back: back)
        }
    }
}

enum NoteExporter {
    enum Format: String, CaseIterable, Identifiable {
        case markdown
        case plainText
        case pdf
        var id: String { rawValue }
        var title: String { self == .plainText ? "Plain Text" : rawValue.capitalized }
        var fileExtension: String { self == .markdown ? "md" : (self == .plainText ? "txt" : "pdf") }
    }

    @MainActor
    static func export(note: LibraryItem, format: Format) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitized(note.title) + "." + format.fileExtension
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data: Data
                switch format {
                case .markdown: data = Data(note.noteMarkdown.utf8)
                case .plainText: data = Data(LibraryFeatures.plainText(from: note.noteMarkdown).utf8)
                case .pdf: data = pdfData(title: note.title, body: LibraryFeatures.plainText(from: note.noteMarkdown))
                }
                try data.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    private static func sanitized(_ title: String) -> String {
        let value = title.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Untitled Note" : value
    }

    private static func pdfData(title: String, body: String) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
        let text = NSMutableAttributedString(string: title + "\n\n" + body)
        text.addAttributes([.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black], range: NSRange(location: 0, length: text.length))
        text.addAttributes([.font: NSFont.systemFont(ofSize: 24, weight: .bold)], range: NSRange(location: 0, length: (title as NSString).length))
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var location = 0
        while location < text.length {
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: CGRect(x: 54, y: 54, width: 504, height: 684), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            location += max(visible.length, 1)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}
