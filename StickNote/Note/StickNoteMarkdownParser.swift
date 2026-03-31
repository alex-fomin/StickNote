import Foundation
import SwiftUI
import Textual

/// Wraps Textual’s Markdown parser and clears SwiftUI font attributes on heading runs.
/// Foundation’s Markdown attaches large per-run fonts to `#` / `##` text; Textual’s `TextBuilder`
/// prefers those over the environment font, so headings stayed huge even with `fontScale(1)`.
struct StickNoteMarkdownParser: MarkupParser {
    private let inner = AttributedStringMarkdownParser.markdown()

    func attributedString(for input: String) throws -> AttributedString {
        var str = try inner.attributedString(for: input)
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
}
