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
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    private var windowTracker: WindowPositionTracker

    var body: some View {
        let font = Font(note.nsFont)
        let fontColor = Color.fromString(note.fontColor)
        let color = Color.fromString(note.color)

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
                    .lineSpacing(note.nsFont.leading)
                    .font(font)
                    .background(color)
                    .foregroundStyle(fontColor)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .onChange(of: note.text) { _, _ in
                        self.minMaxWindow()
                    }
                    .frame(
                        width: note.width, height: note.height,
                        alignment: .topLeading)
                    //.border(.red)

            } else {
                Text($note.text.wrappedValue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // Allow multiple lines in display mode
                    .background(color)
                    .foregroundStyle(fontColor)
                    .font(font)
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
                            note.showOnAllSpaces = !note.showOnAllSpaces
                            if (note.showOnAllSpaces){
                                self.nsWindow?.collectionBehavior.insert(.canJoinAllSpaces)
                            } else {
                                self.nsWindow?.collectionBehavior.remove(.canJoinAllSpaces)
                            }
                        } label: {
                            Label((note.showOnAllSpaces ?"✓ " :"" )+"Show on all spaces", systemImage: "rectangle.on.rectangle")
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
                                self.nsWindow?.close()
                                AppState.shared.deleteNote(note)
                            }
                        } label: {
                            Label("Delete", systemImage: "delete")
                        }
                    }.padding([.horizontal], 5)
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
        .frame(width: note.width, height: note.height, alignment: .leading)
    }

    func processNote() {
        if $note.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.note)
        }
    }

    func minMaxWindow(minimize: Bool = false) {
        let text = minimize ? note.text.truncate(5) : note.text
        let size = text.sizeUsingFont(usingFont: note.nsFont)

        let newX = note.x!
        let newHeight = size.height + (minimize ? 0 : note.nsFont.maximumAdvancement.height)
        let newY = note.y! + note.height! - newHeight
        let newWidth = size.width + "m".sizeUsingFont(usingFont: note.nsFont).width*2

        note.width = newWidth
        note.height = newHeight
        note.x = newX
        note.y = newY
    }
}
