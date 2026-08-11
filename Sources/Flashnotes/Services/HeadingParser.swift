import Foundation

struct MarkdownHeading: Identifiable, Equatable {
    let id: UUID
    let level: Int
    let title: String
    let range: NSRange
    var children: [MarkdownHeading]

    init(id: UUID = UUID(), level: Int, title: String, range: NSRange, children: [MarkdownHeading] = []) {
        self.id = id
        self.level = level
        self.title = title
        self.range = range
        self.children = children
    }
}

enum HeadingParser {
    static func flatHeadings(in markdown: String) -> [MarkdownHeading] {
        var result: [MarkdownHeading] = []
        var location = 0
        markdown.enumerateLines { line, _ in
            let nsLine = line as NSString
            var level = 0
            while level < min(6, nsLine.length), nsLine.character(at: level) == 35 { level += 1 }
            if level > 0, nsLine.length > level, nsLine.character(at: level) == 32 {
                let title = nsLine.substring(from: level + 1).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    result.append(MarkdownHeading(level: level, title: title, range: NSRange(location: location, length: nsLine.length)))
                }
            }
            location += nsLine.length + 1
        }
        return result
    }

    static func hierarchy(in markdown: String) -> [MarkdownHeading] {
        func build(_ headings: [MarkdownHeading], parentLevel: Int) -> [MarkdownHeading] {
            var result: [MarkdownHeading] = []
            var index = 0
            while index < headings.count {
                var heading = headings[index]
                guard heading.level > parentLevel else { break }
                let childStart = index + 1
                var childEnd = childStart
                while childEnd < headings.count, headings[childEnd].level > heading.level { childEnd += 1 }
                if childEnd > childStart {
                    heading.children = build(Array(headings[childStart..<childEnd]), parentLevel: heading.level)
                }
                result.append(heading)
                index = childEnd
            }
            return result
        }
        return build(flatHeadings(in: markdown), parentLevel: 0)
    }
}
