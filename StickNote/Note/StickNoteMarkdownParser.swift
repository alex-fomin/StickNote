import Foundation
import SwiftUI
import Textual

/// Wraps Textual’s Markdown parser with note-specific preprocessing: single newlines inside a
/// paragraph become hard breaks (CommonMark otherwise collapses them to a space).
struct StickNoteMarkdownParser: MarkupParser {
    private let inner = AttributedStringMarkdownParser.markdown()

    func attributedString(for input: String) throws -> AttributedString {
        let preprocessed = Self.singleNewlinesAsHardBreaksPreservingBlankLines(input)
        return try inner.attributedString(for: preprocessed)
    }

    /// Same preprocessing as ``attributedString(for:)`` (for clipboard export using a different parser).
    static func preprocessedMarkdown(_ input: String) -> String {
        singleNewlinesAsHardBreaksPreservingBlankLines(input)
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
