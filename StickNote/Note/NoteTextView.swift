import SwiftUI

struct NoteTextView: View {
    var note: Note
    var allowSelection: Bool = false
    
    @Binding var isCollapsed: Bool
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(isCollapsed ? note.text.truncate(2) : note.text)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(NoteModifier(note: note))
                .modifier(AllowSelectionModifier(allowSelection: allowSelection))
                .border(Color.gray.opacity(0.2), width: 1)

        }
        .accessibilityLabel("Note text")
        .accessibilityValue(note.text)
        .accessibilityHint("Double tap to edit")
    }
}

struct AllowSelectionModifier: ViewModifier {
    var allowSelection: Bool
    
    func body(content: Content) -> some View {
        if allowSelection {
            content
                .textSelection(.enabled)
                .accessibilityAddTraits(.allowsDirectInteraction)
        } else {
            content
        }
    }
}
