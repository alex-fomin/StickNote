import SwiftUI

struct NoteTextView: View {
    var note: Note
    var allowSelection: Bool = false
    
    @Binding var isCollapsed: Bool
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(isCollapsed ? note.text.truncate(NoteView.trimmedLength) : note.text)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(NoteModifier(note: note))
        }
        .accessibilityLabel("Note text")
        .accessibilityValue(note.text)
        .accessibilityHint("Double tap to edit")
    }
}
