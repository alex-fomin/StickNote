import AppKit
import Down
import Foundation
import UniformTypeIdentifiers

/// Rich pasteboard for Markdown: RTF + HTML only (no raw markdown plain text).
/// Uses **Down** (cmark) for CommonMark → HTML, then `NSAttributedString` HTML import → RTF so Pages/iWork
/// get real block structure.
enum MarkdownClipboard {
    /// Writes one pasteboard item with RTF and/or HTML only.
    @MainActor
    static func populatePasteboard(_ pasteboard: NSPasteboard, note: Note) {
        guard let payload = richPayload(for: note) else {
            pasteboard.clearContents()
            return
        }

        let item = NSPasteboardItem()
        item.setData(payload.rtf, forType: .rtf)
        item.setData(payload.htmlUTF8, forType: NSPasteboard.PasteboardType(UTType.html.identifier))

        _ = pasteboard.writeObjects([item])
    }

    private struct RichPayload {
        let rtf: Data
        let htmlUTF8: Data
    }

    /// CommonMark → HTML (cmark) → attributed string → black text → RTF + HTML data.
    @MainActor
    private static func richPayload(for note: Note) -> RichPayload? {
        guard note.isMarkdown, !note.text.isEmpty else { return nil }

        let md = StickNoteMarkdownParser.preprocessedMarkdown(note.text)
        let htmlBody: String
        do {
            htmlBody = try Down(markdownString: md).toHTML(.default)
        } catch {
            return nil
        }

        let htmlDoc =
            """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8"></head><body>\(htmlBody)</body></html>
            """
        guard let htmlUTF8 = htmlDoc.data(using: .utf8) else { return nil }

        let readOpts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard
            let attributed = try? NSAttributedString(
                data: htmlUTF8,
                options: readOpts,
                documentAttributes: nil),
            attributed.length > 0
        else { return nil }

        let ns = NSMutableAttributedString(attributedString: attributed)
        let full = NSRange(location: 0, length: ns.length)
        ns.removeAttribute(.backgroundColor, range: full)
        ns.addAttribute(.foregroundColor, value: NSColor.black, range: full)

        guard
            let rtf = try? ns.data(
                from: full,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.rtf,
                ])
        else { return nil }

        return RichPayload(rtf: rtf, htmlUTF8: htmlUTF8)
    }
}
