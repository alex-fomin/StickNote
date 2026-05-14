import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \NoteLayout.name) var layouts: [NoteLayout]

    @Binding var note: Note
    /// When set with more than one note, choosing a layout applies it to each note (multi-selected floating notes).
    var bulkApplyTargets: [Note]? = nil

    private var notesToApplyLayout: [Note] {
        if let bulk = bulkApplyTargets, bulk.count > 1 { return bulk }
        return [note]
    }

    var body: some View {
        VStack {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                Button {
                    for n in notesToApplyLayout {
                        n.apply(layout: layout)
                    }
                } label: {
                    let sameLayout = notesToApplyLayout.allSatisfy { $0.isSameAppearance(layout) }
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
