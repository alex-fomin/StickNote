import SwiftUI

struct NoteTextView: View {
    var note: Note
    var allowSelection: Bool = false

    var body: some View {
        Text(note.text)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .modifier(NoteModifier(note: note))
            .modifier(AllowSelectionModifier(allowSelection: allowSelection))
    }
}

struct AllowSelectionModifier: ViewModifier {
    var allowSelection: Bool
    func body(content: Content) -> some View {
        if allowSelection {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}
