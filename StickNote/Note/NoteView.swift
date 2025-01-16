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
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.maximizeOnHover) var maximizeOnHover

    @State var note: Note
    @State var nsWindow: NSWindow?
    @State private var isEditing: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    @State var width: CGFloat = 0
    @State var height: CGFloat = 0
    
    private var windowTracker: WindowPositionTracker

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
                    }
                    .lineSpacing(note.nsFont.leading)
                    .modifier(NoteModifier(note: note))
                    .scrollDisabled(true)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .onChange(of: note.text) { _, _ in
                        self.minMaxWindow(minimize: false)
                    }

                    .frame(
                        width: width, height: height,
                        alignment: .topLeading)

            } else {
                NoteTextView(note: note)
                    .overlay(DraggableArea(isEditing: $isEditing))
                    .contextMenu {
                        Button {
                            self.minMaxWindow(minimize: !note.isMinimized)
                            note.isMinimized = !note.isMinimized
                        } label: {
                            Label(note.isMinimized ? "Maximize" : "Minimize", systemImage: "")
                        }
                        Divider()
                        Button {
                            note.showOnAllSpaces = !note.showOnAllSpaces
                            AppState.shared.applyShowOnAllSpaces(note: note)
                        } label: {
                            Label(
                                (note.showOnAllSpaces ? "✓ " : "") + "Show on all spaces",
                                systemImage: "rectangle.on.rectangle")
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
                    }
                    .padding([.horizontal], 5)
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            Button {
                AppState.shared.deleteNote(self.note)
                nsWindow?.close()
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
        .frame(width: width, height: height, alignment: .leading)
        .onAppear {
            minMaxWindow(minimize: note.isMinimized && !isEditing)
        }
        .onHover { hover in
            if !note.isMinimized {
                return
            }
            if maximizeOnHover {
                minMaxWindow(minimize: !hover)
            }
        }
        .onChange(of: note.fontSize) {
            minMaxWindow()
        }
        .onChange(of: note.fontName) {
            minMaxWindow()
        }
    }

    func processNote() {
        if $note.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.note, forceDelete: true)
            nsWindow?.close()
        } else {
            if maximizeOnEdit {
                note.isMinimized = false
            }
            minMaxWindow(minimize: note.isMinimized)
        }
    }

    func minMaxWindow(minimize: Bool = false) {
        let text = minimize ? note.text.truncate(5) : note.text
        let size = text.sizeUsingFont(usingFont: note.nsFont)

        let newHeight = size.height
        let newY = height == 0 ? note.y : (note.y! + height - newHeight)
        let newWidth = size.width + "m".sizeUsingFont(usingFont: note.nsFont).width * 2

        width = newWidth
        height = newHeight
        note.y = newY
    }
}

extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
            self.isAutomaticDashSubstitutionEnabled = false
            self.isAutomaticTextCompletionEnabled = false
        }
    }
}
