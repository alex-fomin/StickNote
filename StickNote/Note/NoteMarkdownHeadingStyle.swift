import SwiftUI
import Textual

/// Heading block spacing and weight; font size comes from the note’s `.font` after
/// ``StickNoteMarkdownParser`` strips oversized run fonts from `#` / `##` spans.
struct NoteUniformHeadingStyle: StructuredText.HeadingStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.lineSpacing(.fontScaled(0.1))
            .textual.blockSpacing(.fontScaled(top: 0.75, bottom: 0.35))
            .fontWeight(.semibold)
    }
}
