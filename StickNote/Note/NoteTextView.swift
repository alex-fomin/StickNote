import SwiftUI
import Textual

struct NoteTextView: View {
    var note: Note
    var allowSelection: Bool = false

    @Binding var isCollapsed: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Group {
                if note.isMarkdown, !isCollapsed {
                    StructuredText(note.text, parser: StickNoteMarkdownParser())
                        .textual.textSelection(.enabled)
                        .textual.structuredTextStyle(StickNoteStructuredTextStyle())
                        .font(Font(note.nsFont))
                        .foregroundStyle(Color.fromString(note.fontColor))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.fromString(note.color))
                        .id("\(note.fontSize)-\(note.fontName)")
                } else {
                    Text(isCollapsed ? note.text.truncate(NoteView.trimmedLength) : note.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(NoteModifier(note: note))
                }
            }
        }
        .accessibilityLabel("Note text")
        .accessibilityValue(note.text)
        .accessibilityHint("Double tap to edit")
    }
}
