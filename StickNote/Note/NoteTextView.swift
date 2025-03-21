import SwiftUI

struct NoteTextView: View {
    var note: Note
    var allowSelection: Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(note.text)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(NoteModifier(note: note))
                .modifier(AllowSelectionModifier(allowSelection: allowSelection))
        }
        .accessibilityLabel("Note text")
        .accessibilityValue(note.text)
        .accessibilityHint("Double tap to edit")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
