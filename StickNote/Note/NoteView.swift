import Defaults
import SwiftData
import SwiftUI

struct NoteView: View {
    // MARK: - Properties
    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.maximizeOnHover) var maximizeOnHover

    @State private var note: Note
    @State private var nsWindow: NSWindow?
    @State private var isEditing: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    
    private let windowTracker: WindowPositionTracker
    private let minPadding: CGFloat = 5
    
    // MARK: - Initialization
    init(note: Note, isEditing: Bool = false) {
        self._note = State(initialValue: note)
        self._isEditing = State(initialValue: isEditing)
        self.windowTracker = WindowPositionTracker(note: note)
    }
    
    // MARK: - Body
    var body: some View {
        HStack() {
            if isEditing {
                editingView
            } else {
                displayView
            }
            if (note.isMinimized){
                Text("...")
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            deleteConfirmationButtons
        }
        .background(Color.fromString($note.color.wrappedValue))
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(windowAccessor)
        .frame(width: width, height: height, alignment: .leading)
        .onAppear { minMaxWindow(minimize: note.isMinimized && !isEditing) }
        .onHover { handleHover($0) }
        .onChange(of: note.fontSize, initial: false) { updateWindowSize() }
        .onChange(of: note.fontName, initial: false) { updateWindowSize() }
        .onChange(of: note.isMinimized, initial: false) { updateWindowSize() }
        .onChange(of: note.text, initial: false) { handleTextChange() }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var editingView: some View {
        TextEditor(text: $note.text, selection: $selection)
            .focused($isTextEditorFocused)
            .onAppear(perform: configureEditingMode)
            .lineSpacing(note.nsFont.leading)
            .modifier(NoteModifier(note: note))
            .scrollDisabled(true)
            .onDisappear { processNote() }
            .onSubmit { processNote() }
            .onChange(of: note.text) { _, _ in
                self.minMaxWindow(minimize: false)
            }
            .submitLabel(.done)
            //.onKeyPress(handleKeyPress)
            .frame(width: width, height: height, alignment: .topLeading)
    }
    
    @ViewBuilder
    private var displayView: some View {
        NoteTextView(note: note)
            .overlay(DraggableArea(isEditing: $isEditing))
            .contextMenu { contextMenuContent }
            .padding(.horizontal, minPadding)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            note.isMinimized.toggle()
        } label: {
            Label(note.isMinimized ? "Maximize" : "Minimize", systemImage: note.isMinimized ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
        }
        
        Button {
            note.trim()
        } label: {
            Label("Trim", systemImage:"trim")
        }
        
        
        Divider()
        
        Button {
            note.showOnAllSpaces.toggle()
            AppState.shared.applyShowOnAllSpaces(note: note)
        } label: {
            Label(
                (note.showOnAllSpaces ? "✓ " : "") + "Show on all spaces",
                systemImage: "rectangle.on.rectangle"
            )
        }
        
        Divider()
        
        Button {
            AppState.shared.copyToClipboard(note)
        } label: {
            Label("Copy to clipboard", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Menu("Layout") {
            LayoutMenu(note: $note)
        }
        
        Divider()
        
        Button(role: .destructive) {
            handleDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button("Delete", role: .destructive) {
            AppState.shared.deleteNote(self.note)
            nsWindow?.close()
        }
        Button("Cancel", role: .cancel) {}
    }
    
    private var windowAccessor: some View {
        WindowAccessor { window in
            self.nsWindow = window
            window?.styleMask.remove(.titled)
            window?.backgroundColor = NSColor.fromString($note.color.wrappedValue)
            window?.delegate = self.windowTracker
            window?.level = .floating
        }
    }
    
    // MARK: - Methods
    private func configureEditingMode() {
        self.nsWindow?.styleMask.insert(.titled)
        isTextEditorFocused = true
        selection = TextSelection(
            range: note.text.startIndex..<note.text.endIndex
        )
        self.nsWindow?.makeKey()
        self.nsWindow?.styleMask.remove(.titled)
    }
    
    private func handleHover(_ hover: Bool) {
        guard note.isMinimized && maximizeOnHover else { return }
        minMaxWindow(minimize: !hover)
    }
    
    private func handleDelete() {
        if confirmOnDelete {
            showConfirmation = true
        } else {
            self.nsWindow?.close()
            AppState.shared.deleteNote(note)
        }
    }
    
//    private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
//        if key.characters == "\r" && key.modifiers == .command {
//            isEditing = false
//            return .handled
//        }
//        return .ignored
//    }
    
    private func handleTextChange() {
        if !note.isMinimized {
            updateWindowSize()
        }
    }
    
    private func updateWindowSize() {
        minMaxWindow(minimize: note.isMinimized)
    }
    
    private func processNote() {
        note.text = note.text.removeTrailingEmptyLines()
        if note.text.isEmpty {
            AppState.shared.deleteNote(self.note, forceDelete: true)
            nsWindow?.close()
        } else if maximizeOnEdit {
            note.isMinimized = false
        }
    }
    
    private func minMaxWindow(minimize: Bool = false) {
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

// MARK: - NSTextView Extension
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
            self.isAutomaticDashSubstitutionEnabled = false
            self.isAutomaticTextCompletionEnabled = false
        }
    }
}
