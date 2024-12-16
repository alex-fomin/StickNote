import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort:\Layout.name) var layouts: [Layout]

    @Binding var color: Color
    @Binding var fontColor: Color
    @Binding var font: NSFont

    var item: Item

    var body: some View {
        HStack {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                Button {
                    item.apply(layout: layout)
                    self.color = Color.fromString(layout.color)
                    self.fontColor = Color.fromString(layout.fontColor)
                    self.font =
                        NSFont(name: item.fontName, size: layout.fontSize)
                        ?? NSFont.systemFont(ofSize: layout.fontSize)

                } label: {
                    Image(
                        systemName: item.color == layout.color
                            ? "checkmark.square.fill" : "square.fill"
                    )
                    .foregroundStyle(
                        item.color == layout.color ? .primary : Color.fromString(layout.color),
                        Color.fromString(layout.color))

                    Label(layout.name, systemImage: "")
                }
            }
        }
    }
}
