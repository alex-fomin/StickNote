import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \NoteLayout.name) var layouts: [NoteLayout]

    @Binding var note: Note

    var body: some View {
        VStack {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                Button {
                    note.apply(layout: layout)
                } label: {
                    let sameLayout = note.isSameAppearance(layout)
                    let swatch = NoteDisplayColors.displayColors(
                        storedBgHex: layout.color,
                        storedFgHex: layout.fontColor,
                        colorScheme: colorScheme
                    )
                    Image(
                        systemName: sameLayout
                            ? "checkmark.square.fill" : "square.fill"
                    )
                    .foregroundStyle(
                        sameLayout ? .primary : swatch.background,
                        swatch.background)

                    Text(layout.name)
                }
            }
            Divider()
            Button("Custom...") {
                openWindow(value: note.persistentModelID)
            }
        }
    }
}

#Preview {
    LayoutMenu(note: .constant(Note(layout: NoteLayout.defaultLayout, text: "note")))
}
