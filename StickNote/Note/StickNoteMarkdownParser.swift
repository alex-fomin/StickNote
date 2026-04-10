import Foundation
import SwiftUI
import Textual

/// Wraps Textual’s Markdown parser and clears SwiftUI font attributes on heading runs.
/// Foundation’s Markdown attaches large per-run fonts to `#` / `##` text; Textual’s `TextBuilder`
/// prefers those over the environment font, so headings stayed huge even with `fontScale(1)`.
struct StickNoteMarkdownParser: MarkupParser {
    private let inner = AttributedStringMarkdownParser.markdown()

    func attributedString(for input: String) throws -> AttributedString {
        // CommonMark collapses a single `\n` inside a paragraph into a space. For notes, treat
        // single newlines as real line breaks by turning them into hard breaks (`␠␠\n`), while
        // leaving blank-line paragraph breaks (`\n\n`) unchanged.
        let preprocessed = Self.singleNewlinesAsHardBreaksPreservingBlankLines(input)
        var str = try inner.attributedString(for: preprocessed)
        let headingRanges: [Range<AttributedString.Index>] = str.runs.compactMap { run in
            guard let pi = run.presentationIntent else { return nil }
            let isHeading = pi.components.contains { component in
                if case .header = component.kind { return true }
                return false
            }
            return isHeading ? run.range : nil
        }
        for range in headingRanges {
            str[range].font = nil
        }
        return str
    }

    /// Within each CommonMark “paragraph” (text between `\n\n`), convert lone `\n` to hard line breaks.
    /// Skips regions between triple-backtick fences so fenced code is unchanged.
    private static func singleNewlinesAsHardBreaksPreservingBlankLines(_ s: String) -> String {
        let pieces = s.components(separatedBy: "```")
        guard pieces.count > 1 else {
            return transformParagraphSingleNewlines(s)
        }
        return pieces.enumerated().map { index, piece in
            if index % 2 == 1 {
                return piece
            }
            return transformParagraphSingleNewlines(piece)
        }.joined(separator: "```")
    }

    private static func transformParagraphSingleNewlines(_ s: String) -> String {
        s
            .components(separatedBy: "\n\n")
            .map { paragraph in
                paragraph.replacingOccurrences(of: "\n", with: "  \n")
            }
            .joined(separator: "\n\n")
    }
}
