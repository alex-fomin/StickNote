import SwiftUI

struct LayoutPickerView: View {
    var title: LocalizedStringKey
    @Binding var selectedLayout: NoteLayout?
    var layouts: [NoteLayout]
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: LocalizedStringKey, selectedLayout: Binding<NoteLayout?>, layouts: [NoteLayout]) {
        self.title = title
        self._selectedLayout = selectedLayout
        self.layouts = layouts
    }
    var body: some View {
        return Picker(title, selection: $selectedLayout) {
            ForEach(layouts) { layout in
                let nsFont = layout.nsFont.withSize(NSFont.systemFontSize)
                let swatch = NoteDisplayColors.displayColors(
                    storedBgHex: layout.color,
                    storedFgHex: layout.fontColor,
                    colorScheme: colorScheme
                )

                HStack {
                    Image(
                        systemName: "square.fill"
                    )
                    .foregroundStyle(
                        swatch.background,
                        swatch.background)

                    Text(layout.name)
                        .font(Font(nsFont))

                }.tag(layout)
            }
            if selectedLayout == nil {
                Divider()
                Text("Custom").tag(nil as NoteLayout?)
            }
        }
    }
}
#Preview {
    LayoutPickerView(
        "Picker",
        selectedLayout: .constant(NoteLayout.defaultLayout),
        layouts: NoteLayout.defaultLayouts()
    )
}
