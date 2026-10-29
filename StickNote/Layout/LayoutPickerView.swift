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
                let swatch = Image(nsImage: LayoutMenuSwatch.image(
                    storedBgHex: layout.color,
                    isDark: colorScheme == .dark
                ))
                Text("\(swatch) \(layout.name)")
                    .font(Font(layout.nsFont.withSize(NSFont.systemFontSize)))
                    .tag(layout)
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
