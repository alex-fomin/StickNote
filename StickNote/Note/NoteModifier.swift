import SwiftUI

struct NoteModifier: ViewModifier {
    var note: Note
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let font = Font(note.nsFont)
        let colors = NoteDisplayColors.displayColors(
            storedBgHex: note.color,
            storedFgHex: note.fontColor,
            colorScheme: colorScheme
        )

        content
            .background(colors.background)
            .foregroundStyle(colors.foreground)
            .font(font)
            .scrollContentBackground(.hidden)
    }
}
