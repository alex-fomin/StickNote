import SwiftUI

struct LayoutPickerView: View {
    var title: LocalizedStringKey
    @Binding var selectedLayout: NoteLayout?
    var layouts: [NoteLayout]

    init(_ title: LocalizedStringKey, selectedLayout: Binding<NoteLayout?>, layouts: [NoteLayout]) {
        self.title = title
        self._selectedLayout = selectedLayout
        self.layouts = layouts
    }
    var body: some View {
        Picker(title, selection: $selectedLayout) {
            ForEach(layouts) { layout in
                let nsFont = NSFont(layout).withSize(NSFont.systemFontSize)

                return HStack {
                    Image(
                        systemName: "square.fill"
                    )
                    .foregroundStyle(
                        Color.fromString(layout.color),
                        Color.fromString(layout.color))

                    Text(layout.name)
                        .font(Font(nsFont))

                }.tag(layout)
            }
        }
    }
}
