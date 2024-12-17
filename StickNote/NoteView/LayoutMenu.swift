import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Query(sort: \Layout.name) var layouts: [Layout]

    @Binding var note: Note

    var body: some View {
        VStack {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                Button {
                    note.apply(layout: layout)
                } label: {
                    let sameLayout =
                        note.color == layout.color && note.fontName == layout.fontName
                        && note.fontSize == layout.fontSize && note.fontColor == layout.fontColor
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
