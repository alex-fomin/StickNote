import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Query(sort: \NoteLayout.name) var layouts: [NoteLayout]

    @Binding var note: Note

    var body: some View {
        VStack {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                Button {
                    note.apply(layout: layout)
                } label: {
                    let sameLayout = note.isSameAppearance(layout)
                    Image(
                        systemName: sameLayout
                            ? "checkmark.square.fill" : "square.fill"
                    )
                    .foregroundStyle(
                        sameLayout ? .primary : Color.fromString(layout.color),
                        Color.fromString(layout.color))

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
