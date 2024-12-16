import SwiftData
import SwiftUI

struct NoteView: View {
    init(item: Item, isEditing: Bool = false) {
        self.item = item
        self.isEditing = isEditing
        self.windowTracker = WindowPositionTracker(item: item)
        self.color = Color.fromString(item.color)
        self.font =
            NSFont(name: item.fontName, size: item.fontSize)
            ?? NSFont.systemFont(ofSize: item.fontSize)
        self.fontColor = Color.fromString(item.fontColor)
    }

    @Bindable var item: Item
    @State var nsWindow: NSWindow?

    @State private var isEditing: Bool

    @FocusState private var isTextEditorFocused: Bool  // Track focus on the TextEditor
    @State var font: NSFont
    @State var color: Color
    @State var fontColor: Color

    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    private var windowTracker: WindowPositionTracker

    var body: some View {
        ZStack {
            if isEditing {
                TextEditor(text: $item.text, selection: $selection)
                    .focused($isTextEditorFocused)  // Bind focus state
                    .onAppear {
                        self.nsWindow?.styleMask.insert(.titled)
                        isTextEditorFocused = true  // Automatically focus
                        selection = TextSelection(
                            range: $item.text.wrappedValue
                                .startIndex..<$item.text.wrappedValue.endIndex)

                        self.nsWindow?.makeKey()
                        self.nsWindow?.styleMask.remove(.titled)
                    }
                    .font(Font(font))
                    .background(color)
                    .foregroundStyle(fontColor)
                    .scrollContentBackground(.hidden)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text($item.text.wrappedValue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // Allow multiple lines in display mode
                    .background(color)
                    .foregroundStyle(fontColor)
                    .font(Font(font))
                    .padding([.horizontal], 5)
                    .overlay(DraggableArea(isEditing: $isEditing))
                    .contextMenu {
                        Button {
                            AppState.shared.copyToClipboard(item)
                        } label: {
                            Label("Copy to clipboard", systemImage: "copy")
                        }
                        Divider()
                        Menu("Layout") {
                            LayoutMenu(
                                color: $color, fontColor: $fontColor, font: $font, item: item)
                        }
                        Button {
                            let fontPicker = FontPicker(self)
                            fontPicker.changeFont()
                        } label: {
                            Label("Change font...", systemImage: "")
                        }

                        Divider()
                        Button {
                            showConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "delete")
                        }
                    }
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(item.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            Button {
                AppState.shared.deleteNote(self.item)
            } label: {
                Text("Delete")
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(color)
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(
            WindowAccessor { window in
                self.nsWindow = window
                window?.styleMask.remove(.titled)
                window?.backgroundColor = NSColor(self.color)
                window?.delegate = self.windowTracker
            }
        )
        .onChange(of: color) { _, newValue in
            self.nsWindow?.backgroundColor = NSColor(self.color)
        }
        .onChange(of: font) { _, newValue in
            self.item.fontName = newValue.fontName
            self.item.fontSize = newValue.pointSize
        }
    }

    func processNote() {
        if $item.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.item)
        }
    }
}


