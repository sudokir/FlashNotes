import AppKit
import Foundation
import UniformTypeIdentifiers

enum AttachmentStoreError: Error {
    case invalidImage
    case encodingFailed
}

struct AttachmentStore {
    let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.rootURL = support.appending(path: "Flashnotes/Attachments", directoryHint: .isDirectory)
        }
    }

    func saveImage(data: Data) throws -> String {
        guard let image = NSImage(data: data) else { throw AttachmentStoreError.invalidImage }
        let resized = image.resized(maxDimension: 2200)
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let encoded = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.84]) else {
            throw AttachmentStoreError.encodingFailed
        }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString.lowercased()).jpg"
        try encoded.write(to: rootURL.appending(path: name), options: .atomic)
        return Self.reference(for: name)
    }

    func url(for reference: String) -> URL? {
        guard let name = Self.filename(from: reference) else { return nil }
        return rootURL.appending(path: name)
    }

    func removeAttachments(referencedIn texts: [String]) {
        let names = Set(texts.flatMap(Self.filenames(in:)))
        for name in names { try? FileManager.default.removeItem(at: rootURL.appending(path: name)) }
    }

    func duplicateReferences(in markdown: String) -> String {
        var result = markdown
        for name in Set(Self.filenames(in: markdown)) {
            let source = rootURL.appending(path: name)
            let extensionName = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
            let newName = "\(UUID().uuidString.lowercased()).\(extensionName)"
            let destination = rootURL.appending(path: newName)
            do {
                try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: destination)
                result = result.replacingOccurrences(of: Self.reference(for: name), with: Self.reference(for: newName))
            } catch {
                continue
            }
        }
        return result
    }

    static func reference(for filename: String) -> String { "attachment://\(filename)" }

    static func filename(from reference: String) -> String? {
        guard reference.hasPrefix("attachment://") else { return nil }
        let name = String(reference.dropFirst("attachment://".count))
        guard !name.isEmpty, !name.contains("/"), !name.contains("..") else { return nil }
        return name
    }

    static func filenames(in markdown: String) -> [String] {
        let pattern = #"attachment://([A-Za-z0-9._-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let swiftRange = Range(match.range(at: 1), in: markdown) else { return nil }
            return String(markdown[swiftRange])
        }
    }
}

private extension NSImage {
    func resized(maxDimension: CGFloat) -> NSImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension, largest > 0 else { return self }
        let scale = maxDimension / largest
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize))
        result.unlockFocus()
        return result
    }
}
