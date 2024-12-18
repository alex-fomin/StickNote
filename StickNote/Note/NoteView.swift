import Defaults
import SwiftData
import SwiftUI

struct NoteView: View {
    init(note: Note, isEditing: Bool = false) {
        self.note = note
        self.isEditing = isEditing
        self.windowTracker = WindowPositionTracker(note: note)
    }
    @Default(.confirmOnDelete) var confirmOnDelete

    @State var note: Note
    @State var nsWindow: NSWindow?

    @State private var isEditing: Bool

    @FocusState private var isTextEditorFocused: Bool  // Track focus on the TextEditor

    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    private var windowTracker: WindowPositionTracker

    func getFont() -> Font {
        let nsFont =
            NSFont(name: $note.fontName.wrappedValue, size: $note.fontSize.wrappedValue)
            ?? NSFont.systemFont(ofSize: $note.fontSize.wrappedValue)
        return Font(nsFont)
    }

    func getFontColor() -> Color { Color.fromString($note.fontColor.wrappedValue) }

    func getColor() -> Color { Color.fromString($note.color.wrappedValue) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isEditing {
                TextEditor(text: $note.text, selection: $selection)
                    .focused($isTextEditorFocused)  // Bind focus state
                    .onAppear {
                        self.nsWindow?.styleMask.insert(.titled)
                        isTextEditorFocused = true  // Automatically focus
                        selection = TextSelection(
                            range: $note.text.wrappedValue
                                .startIndex..<$note.text.wrappedValue.endIndex)

                        self.nsWindow?.makeKey()
                        self.nsWindow?.styleMask.remove(.titled)

                        self.minMaxWindow()
                    }
                    .font(getFont())
                    .background(getColor())
                    .foregroundStyle(getFontColor())
                    .scrollContentBackground(.hidden)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text($note.text.wrappedValue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // Allow multiple lines in display mode
                    .background(getColor())
                    .foregroundStyle(getFontColor())
                    .font(getFont())
                    .padding([.horizontal], 5)
                    .overlay(DraggableArea(isEditing: $isEditing))
                    .contextMenu {
                        Button {
                            self.minMaxWindow(minimize: true)
                        } label: {
                            Label("Minimize", systemImage: "")
                        }
                        Button {
                            self.minMaxWindow()
                        } label: {
                            Label("Maximize", systemImage: "")
                        }
                        Divider()
                        Button {
                            AppState.shared.copyToClipboard(note)
                        } label: {
                            Label("Copy to clipboard", systemImage: "copy")
                        }
                        Divider()
                        Menu("Layout") {
                            LayoutMenu(note: $note)
                        }
                        Divider()
                        Button {
                            if confirmOnDelete {
                                showConfirmation = true
                            } else {
                                AppState.shared.deleteNote(note)
                            }
                        } label: {
                            Label("Delete", systemImage: "delete")
                        }
                    }
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            Button {
                AppState.shared.deleteNote(self.note)
            } label: {
                Text("Delete")
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(Color.fromString($note.color.wrappedValue))
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(
            WindowAccessor { window in
                self.nsWindow = window
                window?.styleMask.remove(.titled)
                window?.backgroundColor = NSColor.fromString($note.color.wrappedValue)
                window?.delegate = self.windowTracker
            }
        )
    }

    func processNote() {
        if $note.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.note)
        }
    }

    func minMaxWindow(minimize: Bool = false) {
        let text = minimize ? "ABC" : note.text
        let size = text.sizeUsingFont(usingFont: note.nsFont)

        let newY = note.y! + note.height! - size.height
        let newWidth = size.width + 10
        let newFrame = NSRect(
            x: note.x!, y: newY, width: newWidth,
            height: size.height)
        self.nsWindow?.setFrame(newFrame, display: true, animate: true)

        note.width = newWidth
        note.height = size.height
        note.y = newY
    }
}
