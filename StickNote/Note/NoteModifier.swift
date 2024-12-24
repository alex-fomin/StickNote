import SwiftUI

struct NoteModifier: ViewModifier {
    var note:Note
    func body(content: Content) -> some View {
        let font = Font(note.nsFont)
        let fontColor = Color.fromString(note.fontColor)
        let color = Color.fromString(note.color)
        
        content
            .background(color)
            .foregroundStyle(fontColor)
            .font(font)
            .scrollContentBackground(.hidden)
            //.lineSpacing(note.nsFont.leading)
    }
}
