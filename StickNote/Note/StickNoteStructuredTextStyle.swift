import SwiftUI
import Textual

/// Same block/inline setup as ``StructuredText/DefaultStyle``, but headings use
/// ``NoteUniformHeadingStyle`` instead of ``StructuredText/DefaultHeadingStyle``.
///
/// Applying ``TextualNamespace/headingStyle(_:)`` *after* ``structuredTextStyle(.default)`` does not
/// work: the default style’s inner `environment(\.headingStyle, …)` overrides an outer heading style
/// for the rendered document, so `#` / `##` still get the large default scales.
struct StickNoteStructuredTextStyle: StructuredText.Style {
    let inlineStyle: InlineStyle = .default
    let headingStyle: NoteUniformHeadingStyle = NoteUniformHeadingStyle()
    let paragraphStyle: StructuredText.DefaultParagraphStyle = .default
    let blockQuoteStyle: StructuredText.DefaultBlockQuoteStyle = .default
    let codeBlockStyle: StructuredText.DefaultCodeBlockStyle = .default
    let listItemStyle: StructuredText.DefaultListItemStyle = .default
    let unorderedListMarker: StructuredText.SymbolListMarker = .disc
    let orderedListMarker: StructuredText.DecimalListMarker = .decimal
    let tableStyle: StructuredText.DefaultTableStyle = .default
    let tableCellStyle: StructuredText.DefaultTableCellStyle = .default
    let thematicBreakStyle: StructuredText.DividerThematicBreakStyle = .divider
}
