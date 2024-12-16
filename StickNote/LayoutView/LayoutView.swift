import FontPicker
import SwiftUI

struct NoteLayoutView: View {
    @State var note: Note
    init(note: Note) {
        self.note = note
    }
    var body: some View {
        LayoutView(info: note)
    }
}

struct LayoutView: View {
    @Environment(\.modelContext) var modelContext
    @State var info: NoteAppearance
    @State var font: NSFont
    @State var color: Color
    @State var fontColor: Color
    init(info: NoteAppearance) {
        self.info = info
        self.font = NSFont(info)
        self.color = Color.fromString(info.color)
        self.fontColor = Color.fromString(info.fontColor)
    }

    var body: some View {
        VStack {
            Spacer()
            Text("Lorem ipsum")
                .font(Font(font))
                .foregroundStyle(fontColor)
                .background(color)
            Text(info.fontColor)
            Text(info.color)
            Spacer()
            FontPicker("Choose font", selection: $font)
            ColorPicker("Choose background", selection: $color)
            ColorPicker("Choose font color", selection: $fontColor)
        }
        .onChange(of: font) { _, newValue in
            info.fontName = newValue.fontName
            info.fontSize = newValue.pointSize
            try? modelContext.save()
        }
        .onChange(of: color) {
            info.color = $1.toHex()
            
            try? modelContext.save()
            
        }
        .onChange(of: fontColor) {
            info.fontColor = $1.toHex()
            try? modelContext.save()
        }
    }
}

#Preview {
    LayoutView(info: Layout.defaultLayouts().first(where: { $0.name == "Alert" })!)
    //   LayoutView(layout: Layout.defaultLayout)
}
