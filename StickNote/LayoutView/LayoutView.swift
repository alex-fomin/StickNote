import FontPicker
import Foundation
import SwiftData
import SwiftUI

struct NoteLayoutView: View {
    @State var note: Note
    init(note: Note) {
        self.note = note
    }
    var body: some View {
        LayoutView(info: note, text: note.text)
    }
}

struct LayoutInfo: Hashable {
    var text: String
    var color: String? = nil

}

struct LayoutView: View {
    @Environment(\.modelContext) var modelContext
    @Query var layouts: [Layout]

    @State var info: NoteAppearance
    @State var font: NSFont
    @State var color: Color
    @State var fontColor: Color
    @State var text: String
    @State var layoutsWithNewPlaceholder: [LayoutInfo] = []

    @State var selectedLayoutIndex: Int = -3
    @State private var showingAlert = false

    @State var newLayoutName: String = ""

    init(info: NoteAppearance, text: String? = nil) {
        self.info = info
        self.font = NSFont(info)
        self.color = Color.fromString(info.color)
        self.fontColor = Color.fromString(info.fontColor)
        self.text =
            text
            ?? "Est veniam mollit commodo laboris\nex exercitation sint amet"

    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                VStack(alignment: .trailing) {
                    FontPicker("Font", selection: $font)
                    ColorPicker("Background", selection: $color)
                    ColorPicker("Font color", selection: $fontColor)
                }
                Text(text)
                    .font(Font(font))
                    .foregroundStyle(fontColor)
                    .background(color)
                    .padding(.all)
                    .frame(maxWidth: 200, maxHeight: 150)
            }
            HStack(alignment: .bottom) {
                Picker("Save as layout", selection: $selectedLayoutIndex) {
                    ForEach(self.layouts.indices, id: \.self) {
                        let layout = self.layouts[$0]
                        HStack {
                            Image(
                                systemName: "square.fill"
                            )
                            .foregroundStyle(
                                Color.fromString(layout.color),
                                Color.fromString(layout.color))
                            Text(layout.name)
                        }
                    }
                    Text("New...").tag(Int.max)
                }
                Button("Save layout") {
                    if $selectedLayoutIndex.wrappedValue < Int.max {
                        let layout = self.layouts[$selectedLayoutIndex.wrappedValue]

                        layout.fontName = $font.wrappedValue.fontName
                        layout.fontSize = $font.wrappedValue.pointSize
                        layout.color = $color.wrappedValue.toHex()
                        layout.fontColor = $fontColor.wrappedValue.toHex()
                        try? self.modelContext.save()
                    } else {
                        showingAlert = true
                    }
                }
                .alert("Enter layout name", isPresented: $showingAlert) {
                    TextField("Enter layout name", text: $newLayoutName)
                    Button("Save") {
                        let layout = Layout(
                            name: $newLayoutName.wrappedValue,
                            color: $color.wrappedValue.toHex(),
                            fontName: $font.wrappedValue.fontName,
                            fontSize: $font.wrappedValue.pointSize,
                            fontColor: $fontColor.wrappedValue.toHex())

                        self.modelContext.insert(layout)
                        try? self.modelContext.save()
                        selectedLayoutIndex = layouts.count - 1
                    }
                }
                .disabled($selectedLayoutIndex.wrappedValue < 0)
            }
        }
        .padding()
        .onChange(of: font) { _, newValue in
            info.fontName = newValue.fontName
            info.fontSize = newValue.pointSize
            try? modelContext.save()
        }
        .onChange(of: color) { _, color in
            info.color = color.toHex()
            if color.isLight() && fontColor.toHex() == "#FFFFFF" {
                fontColor = Color.fromString("#000000")
            } else if !color.isLight() && fontColor.toHex() == "#000000" {
                fontColor = Color.fromString("#FFFFFF")
            }

            try? modelContext.save()

        }
        .onChange(of: fontColor) {
            info.fontColor = $1.toHex()
            try? modelContext.save()
        }
    }
}

#Preview {
    LayoutView(info: Layout.defaultLayout)
}
