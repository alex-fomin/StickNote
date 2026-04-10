import SwiftUI
import Textual

/// Textual’s default per-level font scale and line spacing, with **uniform** block spacing for every heading level.
struct NoteUniformHeadingStyle: StructuredText.HeadingStyle {
    private static let lineSpacings: [CGFloat] = [0, 0.10, 0.07, 0.08, 0.09, 0.22]
    private static let fontScales: [CGFloat] = [2.353, 1.882, 1.647, 1.412, 1.294, 1]
    private static let uniformBlockTop: CGFloat = 0.48
    private static let uniformBlockBottom: CGFloat = 0.24

    func makeBody(configuration: Configuration) -> some View {
        let headingLevel = min(configuration.headingLevel, 6)
        let lineSpacing = Self.lineSpacings[headingLevel - 1]
        let fontScale = Self.fontScales[headingLevel - 1]

        configuration.label
            .textual.fontScale(fontScale)
            .textual.lineSpacing(.fontScaled(lineSpacing))
            .textual.blockSpacing(.fontScaled(top: Self.uniformBlockTop, bottom: Self.uniformBlockBottom))
            .fontWeight(.semibold)
    }
}

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
