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
//                    self.color = Color.fromString(layout.color)
//                    self.fontColor = Color.fromString(layout.fontColor)
//                    self.font = NSFont(note)
                } label: {
                    Image(
                        systemName: note.color == layout.color
                            ? "checkmark.square.fill" : "square.fill"
                    )
                    .foregroundStyle(
                        note.color == layout.color ? .primary : Color.fromString(layout.color),
                        Color.fromString(layout.color))

                    Label(layout.name, systemImage: "")
                }
            }
            Divider()
            Button("Custom..."){
                openWindow(value: note.persistentModelID)
            }
        }
    }
}
//
//#Preview {
//    @Previewable @State var note = Note(
//        text: "NoteYellow", color: "#FFF68B", fontName: "", fontSize: 14, fontColor: "#000000")
//
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Layout.self, configurations: config)
//
//    for layout in Layout.defaultLayouts() {
//        container.mainContext.insert(layout)
//    }
//    
////    return LayoutMenu(        note:note)
////    .modelContainer(container)
//}
