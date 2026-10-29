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
            .navigationTitle("Layout")
    }
}

struct LayoutView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \NoteLayout.name) var layouts: [NoteLayout]

    @State var info: NoteAppearance
    @State var font: NSFont
    @State var color: Color
    @State var fontColor: Color
    @State var opacity: Double
    @State var text: String

    @State private var selectedLayoutID: PersistentIdentifier?
    @State private var showingNewLayoutAlert = false
    @State private var newLayoutName: String = ""

    private var layoutPreviewDisplayColors: (background: Color, foreground: Color) {
        NoteDisplayColors.displayColors(
            storedBgHex: color.toHex(),
            storedFgHex: fontColor.toHex(),
            colorScheme: colorScheme
        )
    }

    private var sortedLayouts: [NoteLayout] {
        layouts.sorted { a, _ in a.isDefault }
    }

    private var selectedLayout: NoteLayout? {
        layouts.first { $0.persistentModelID == selectedLayoutID }
    }

    private var isModified: Bool {
        guard let layout = selectedLayout else { return false }
        return layout.color != color.toHex() || layout.fontColor != fontColor.toHex()
            || layout.fontName != font.fontName || layout.fontSize != font.pointSize
            || abs(layout.opacity - opacity) >= 0.01
    }

    /// Picking a light background swaps white text for black (and the reverse). Only for user edits, not applied layouts.
    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { color },
            set: { newColor in
                color = newColor
                if newColor.isLight() && fontColor.toHex() == "#FFFFFF" {
                    fontColor = Color.fromString("#000000")
                } else if !newColor.isLight() && fontColor.toHex() == "#000000" {
                    fontColor = Color.fromString("#FFFFFF")
                }
            }
        )
    }

    private var layoutSelection: Binding<PersistentIdentifier?> {
        Binding(
            get: { selectedLayoutID },
            set: { id in
                selectedLayoutID = id
                if let layout = selectedLayout { apply(layout) }
            }
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
                ColorPicker("Background", selection: backgroundBinding)
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
                LabeledContent("Layout") {
                    HStack(spacing: 8) {
                        Picker("Layout", selection: layoutSelection) {
                            ForEach(sortedLayouts) { layout in
                                let swatch = Image(nsImage: LayoutMenuSwatch.image(
                                    storedBgHex: layout.color,
                                    isDark: colorScheme == .dark
                                ))
                                Text("\(swatch) \(layout.name)")
                                    .tag(Optional(layout.persistentModelID))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        if isModified {
                            Text("modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Revert") {
                        if let layout = selectedLayout { apply(layout) }
                    }
                    .disabled(!isModified)
                    Button("Update", action: updateSelectedLayout)
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!isModified)
                    Button("Save as New…") {
                        newLayoutName = ""
                        showingNewLayoutAlert = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("New layout", isPresented: $showingNewLayoutAlert) {
            TextField("Layout name", text: $newLayoutName)
            Button("Cancel", role: .cancel) {}
            Button("Save", action: saveNewLayout)
                .disabled(newLayoutName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear {
            selectInitialLayout()
            // The size field would otherwise take focus and select its value on open.
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .onChange(of: font) { _, newValue in
            info.fontName = newValue.fontName
            info.fontSize = newValue.pointSize
            try? modelContext.save()
        }
        .onChange(of: color) { _, newValue in
            info.color = newValue.toHex()
            try? modelContext.save()
        }
        .onChange(of: fontColor) { _, newValue in
            info.fontColor = newValue.toHex()
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
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(10)
            .background(layoutPreviewDisplayColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .opacity(opacity)
            .padding(12)
    }

    private func apply(_ layout: NoteLayout) {
        font = layout.nsFont
        color = Color.fromString(layout.color)
        fontColor = Color.fromString(layout.fontColor)
        opacity = min(1, max(0.4, layout.opacity))
    }

    private func updateSelectedLayout() {
        guard let layout = selectedLayout else { return }
        layout.fontName = font.fontName
        layout.fontSize = font.pointSize
        layout.color = color.toHex()
        layout.fontColor = fontColor.toHex()
        layout.opacity = opacity
        try? modelContext.save()
    }

    private func saveNewLayout() {
        let layout = NoteLayout(
            name: newLayoutName.trimmingCharacters(in: .whitespaces),
            color: color.toHex(),
            fontName: font.fontName,
            fontSize: font.pointSize,
            fontColor: fontColor.toHex(),
            opacity: opacity)
        modelContext.insert(layout)
        try? modelContext.save()
        selectedLayoutID = layout.persistentModelID
    }

    /// Exact match first, then a layout with the same background, then the default.
    private func selectInitialLayout() {
        let initial =
            layouts.first { info.isSameAppearance($0) }
            ?? layouts.first { $0.color == info.color }
            ?? layouts.first { $0.isDefault }
            ?? layouts.first
        selectedLayoutID = initial?.persistentModelID
    }
}

#Preview {
    LayoutView(info: NoteLayout.defaultLayout)
}
