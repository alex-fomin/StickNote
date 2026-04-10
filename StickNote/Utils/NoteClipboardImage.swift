import AppKit
import Foundation
import UniformTypeIdentifiers

/// Clipboard images for “Paste note”: export to PNG under Application Support and reference in Markdown.
enum NoteClipboardImage {

    /// Folder where pasted images are stored (`…/Application Support/StickNote/clipboard-images`).
    static func clipboardImagesDirectoryURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("StickNote/clipboard-images", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Removes PNG files under ``clipboardImagesDirectoryURL()`` that are only referenced by `deletedNote`
    /// (safe when another note still embeds the same file).
    static func deleteStoredImagesIfOnlyReferencedByDeletedNote(
        deletedNote: Note,
        allNotes: [Note]
    ) {
        let pathsInDeleted = Set(
            fileURLsUnderClipboardImagesFolder(in: deletedNote.text).map { canonicalFilePath($0) }
        )
        guard !pathsInDeleted.isEmpty else { return }

        for path in pathsInDeleted {
            let referenceCount = allNotes.filter { note in
                Set(fileURLsUnderClipboardImagesFolder(in: note.text).map { canonicalFilePath($0) })
                    .contains(path)
            }.count
            guard referenceCount == 1 else { continue }
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// Whether the general pasteboard can create a note (plain/RTF text, or raster image).
    static func pasteboardCanCreateNote(from pasteboard: NSPasteboard = .general) -> Bool {
        if pasteboardContainsImage(pasteboard) { return true }
        return pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.string.rawValue,
            NSPasteboard.PasteboardType.rtf.rawValue,
            NSPasteboard.PasteboardType.rtfd.rawValue,
        ])
    }

    static func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }
        let types: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType(UTType.png.identifier),
            NSPasteboard.PasteboardType(UTType.tiff.identifier),
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.gif.identifier),
            NSPasteboard.PasteboardType(UTType.webP.identifier),
        ]
        return types.contains { pasteboard.data(forType: $0) != nil }
    }

    /// PNG bytes for embedding in a note (no disk file).
    static func exportPastedImageToPNGData(from pasteboard: NSPasteboard = .general) -> Data? {
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.png.identifier)) {
            return data
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.tiff.identifier)),
           let png = pngData(fromBitmapOrImageData: data)
        {
            return png
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)),
           let png = pngData(fromBitmapOrImageData: data)
        {
            return png
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.gif.identifier)),
           let png = pngData(fromBitmapOrImageData: data)
        {
            return png
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.webP.identifier)),
           let png = pngData(fromBitmapOrImageData: data)
        {
            return png
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let first = images.first,
           let png = pngData(from: first)
        {
            return png
        }
        return nil
    }

    /// Writes PNG data to the app’s clipboard-images folder and returns the file URL, or `nil` if there is no image.
    static func exportPastedImageToPNGFile(from pasteboard: NSPasteboard = .general) -> URL? {
        guard let png = exportPastedImageToPNGData(from: pasteboard) else { return nil }
        return writeFreshPNGFile(png)
    }

    // MARK: - Private

    /// `file:` URLs in `markdownText` that live under ``clipboardImagesDirectoryURL()``.
    private static func fileURLsUnderClipboardImagesFolder(in markdownText: String) -> [URL] {
        let dirURL = clipboardImagesDirectoryURL()
        let dirPath = canonicalFilePath(dirURL)
        var result: [URL] = []
        let pattern = #"!\[[^\]]*\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(markdownText.startIndex..., in: markdownText)
        regex.enumerateMatches(in: markdownText, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2,
                let r = Range(match.range(at: 1), in: markdownText)
            else { return }
            var raw = String(markdownText[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasPrefix("<"), raw.hasSuffix(">") {
                raw = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let url = URL(string: raw), url.isFileURL else { return }
            let path = canonicalFilePath(url)
            guard path.hasPrefix(dirPath + "/") else { return }
            result.append(url)
        }
        return result
    }

    private static func canonicalFilePath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func writeFreshPNGFile(_ pngData: Data) -> URL? {
        let url = clipboardImagesDirectoryURL().appendingPathComponent("\(UUID().uuidString).png")
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func pngData(fromBitmapOrImageData data: Data) -> Data? {
        if let img = NSImage(data: data) {
            return pngData(from: img)
        }
        return nil
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
