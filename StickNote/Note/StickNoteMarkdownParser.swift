import Foundation
import SwiftUI
import Textual

/// Wraps Textual’s Markdown parser with note-specific preprocessing: GitHub-style task list lines
/// (and plain line-leading `[ ]` / `[x]`) become checkbox characters (outside fenced code), then
/// single newlines inside a paragraph become hard breaks (CommonMark otherwise collapses them to a space).
///
/// Glyphs: classic ballot **☐** (U+2610) and **☑** (U+2611). Alternatives: ⬜ U+2B1C, ✔ U+2714, ☒ U+2612, ✅ U+2705.
struct StickNoteMarkdownParser: MarkupParser {
    private let inner = AttributedStringMarkdownParser.markdown()

    private static let uncheckedBox = "\u{2610}" // BALLOT BOX ☐
    private static let checkedBox = "\u{2611}" // BALLOT BOX WITH CHECK ☑

    /// Ordered task: `1. [ ]` / `1. [x]` (body optional).
    private static let orderedTaskLineRegex: NSRegularExpression = {
        // Fixed patterns; failure is a programming error.
        try! NSRegularExpression(
            pattern: #"^(\s*)(\d+\.)\s+\[\s*([xX]?)\s*\](?:\s+(.*))?$"#,
            options: []
        )
    }()

    /// Bullet task: `- [ ]` / `* [x]` (body optional). Inner `[link]`-style text does not match.
    private static let bulletTaskLineRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^(\s*)[-*+]\s+\[\s*([xX]?)\s*\](?:\s+(.*))?$"#,
            options: []
        )
    }()

    /// Plain bracket task: `[ ]` / `[x]` at line start (after optional indent), optional body.
    private static let bareBracketTaskLineRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^(\s*)\[\s*([xX]?)\s*\](?:\s+(.*))?$"#,
            options: []
        )
    }()

    func attributedString(for input: String) throws -> AttributedString {
        let preprocessed = Self.singleNewlinesAsHardBreaksPreservingBlankLines(
            Self.gfmTaskListsPreservingCodeFences(input))
        return try inner.attributedString(for: preprocessed)
    }

    /// Same preprocessing as ``attributedString(for:)`` (for clipboard export using a different parser).
    static func preprocessedMarkdown(_ input: String) -> String {
        singleNewlinesAsHardBreaksPreservingBlankLines(gfmTaskListsPreservingCodeFences(input))
    }

    /// Converts GFM task list lines to plain lines with checkbox glyphs so list bullets are not doubled in Textual.
    /// Skips regions between triple-backtick fences so fenced code is unchanged.
    private static func gfmTaskListsPreservingCodeFences(_ s: String) -> String {
        let pieces = s.components(separatedBy: "```")
        guard pieces.count > 1 else {
            return transformGFMTaskListLines(in: s)
        }
        return pieces.enumerated().map { index, piece in
            if index % 2 == 1 {
                return piece
            }
            return transformGFMTaskListLines(in: piece)
        }.joined(separator: "```")
    }

    private static func transformGFMTaskListLines(in piece: String) -> String {
        piece.components(separatedBy: "\n").map { line in
            transformGFMTaskListLine(line) ?? line
        }.joined(separator: "\n")
    }

    /// Returns a replacement line if `line` is a GFM task item; otherwise `nil`.
    private static func transformGFMTaskListLine(_ line: String) -> String? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)

        if let m = orderedTaskLineRegex.firstMatch(in: line, options: [], range: full) {
            let indent = substring(ns, m.range(at: 1))
            let ordinal = substring(ns, m.range(at: 2))
            let mark = substring(ns, m.range(at: 3))
            let body = substring(ns, m.range(at: 4))
            let box = mark.isEmpty ? uncheckedBox : checkedBox
            if body.isEmpty {
                return "\(indent)\(ordinal) \(box)"
            }
            return "\(indent)\(ordinal) \(box) \(body)"
        }

        if let m = bulletTaskLineRegex.firstMatch(in: line, options: [], range: full) {
            let indent = substring(ns, m.range(at: 1))
            let mark = substring(ns, m.range(at: 2))
            let body = substring(ns, m.range(at: 3))
            let box = mark.isEmpty ? uncheckedBox : checkedBox
            if body.isEmpty {
                return "\(indent)\(box)"
            }
            return "\(indent)\(box) \(body)"
        }

        if let m = bareBracketTaskLineRegex.firstMatch(in: line, options: [], range: full) {
            let indent = substring(ns, m.range(at: 1))
            let mark = substring(ns, m.range(at: 2))
            let body = substring(ns, m.range(at: 3))
            let box = mark.isEmpty ? uncheckedBox : checkedBox
            if body.isEmpty {
                return "\(indent)\(box)"
            }
            return "\(indent)\(box) \(body)"
        }

        return nil
    }

    private static func substring(_ ns: NSString, _ range: NSRange) -> String {
        guard range.location != NSNotFound else { return "" }
        return ns.substring(with: range)
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
