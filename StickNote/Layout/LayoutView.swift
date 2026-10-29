import AppKit
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
    @Environment(\.colorScheme) private var colorScheme
    @Query var layouts: [NoteLayout]

    @State var info: NoteAppearance
    @State var font: NSFont
    @State var color: Color
    @State var fontColor: Color
    @State var opacity: Double
    @State var text: String
    @State var layoutsWithNewPlaceholder: [LayoutInfo] = []

    @State var selectedLayoutIndex: Int = -3
    @State private var showingAlert = false

    @State var newLayoutName: String = ""

    private var layoutPreviewDisplayColors: (background: Color, foreground: Color) {
        NoteDisplayColors.displayColors(
            storedBgHex: color.toHex(),
            storedFgHex: fontColor.toHex(),
            colorScheme: colorScheme
        )
    }

    init(info: NoteAppearance, text: String? = nil) {
        self.info = info
        self.font = info.nsFont
        self.color = Color.fromString(info.color)
        self.fontColor = Color.fromString(info.fontColor)
        self.opacity = min(1, max(0.4, info.opacity))
        self.text =
            text
            ?? "Est veniam mollit commodo laboris\nex exercitation sint amet"

    }

    var body: some View {
        Form {
            Section {
                notePreview
                    .listRowInsets(EdgeInsets())
            }

            Section {
                FontListPicker(font: $font)
                ColorPicker("Background", selection: $color)
                ColorPicker("Font color", selection: $fontColor)
                LabeledContent("Opacity") {
                    HStack(spacing: 8) {
                        Slider(value: $opacity, in: 0.4...1)
                            .frame(width: 160)
                        Text("\(Int((opacity * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } footer: {
                Text(
                    "In dark mode, on-screen note colors are adjusted for readability. Saved layout colors are stored unchanged."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                LabeledContent("Save as") {
                    HStack(spacing: 8) {
                        Picker("Save as", selection: $selectedLayoutIndex) {
                            ForEach(self.layouts.indices, id: \.self) { index in
                                let layout = self.layouts[index]
                                let swatch = Image(nsImage: LayoutMenuSwatch.image(
                                    storedBgHex: layout.color,
                                    isDark: colorScheme == .dark
                                ))
                                Text("\(swatch) \(layout.name)").tag(index)
                            }
                            Divider()
                            Text("New layout…").tag(Int.max)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button("Save", action: saveLayout)
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(selectedLayoutIndex < 0)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("New layout", isPresented: $showingAlert) {
            TextField("Layout name", text: $newLayoutName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let layout = NoteLayout(
                    name: newLayoutName,
                    color: color.toHex(),
                    fontName: font.fontName,
                    fontSize: font.pointSize,
                    fontColor: fontColor.toHex(),
                    opacity: opacity)
                modelContext.insert(layout)
                try? modelContext.save()
                selectedLayoutIndex = layouts.count - 1
            }
            .disabled(newLayoutName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear { selectCurrentLayoutIfNeeded() }
        .onChange(of: layouts.count) { _, _ in selectCurrentLayoutIfNeeded() }
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
        .onChange(of: opacity) { _, newValue in
            info.opacity = newValue
            try? modelContext.save()
            if let note = info as? Note {
                AppState.shared.applyWindowOpacity(for: note)
            }
        }
    }

    private var notePreview: some View {
        Text(text)
            .font(Font(font))
            .foregroundStyle(layoutPreviewDisplayColors.foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(layoutPreviewDisplayColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .opacity(opacity)
            .padding(16)
            .frame(height: 140)
            .clipped()
    }

    private func saveLayout() {
        guard layouts.indices.contains(selectedLayoutIndex) else {
            newLayoutName = ""
            showingAlert = true
            return
        }
        let layout = layouts[selectedLayoutIndex]
        layout.fontName = font.fontName
        layout.fontSize = font.pointSize
        layout.color = color.toHex()
        layout.fontColor = fontColor.toHex()
        layout.opacity = opacity
        try? modelContext.save()
    }

    private func selectCurrentLayoutIfNeeded() {
        guard selectedLayoutIndex < 0 else { return }
        if let index = layouts.firstIndex(where: { info.isSameAppearance($0) }) {
            selectedLayoutIndex = index
        } else if !layouts.isEmpty {
            selectedLayoutIndex = Int.max
        }
    }
}

#Preview {
    LayoutView(info: NoteLayout.defaultLayout)
}
