import Defaults
import SwiftData
import SwiftUI

struct NoteView: View {
    
    static let horizonalPadding: CGFloat = 2
    static let verticalPadding: CGFloat = 2
    static let trimmedLength = 4
    
    
    // MARK: - Properties
    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.maximizeOnHover) var maximizeOnHover
    
    @State private var note: Note
    @State private var isCollapsed: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var isEditing: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false
    @State private var showHideUntilSheet = false
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    
    private let windowTracker: WindowPositionTracker
    
    // MARK: - Initialization
    init(note: Note, isEditing: Bool = false) {
        self._note = State(initialValue: note)
        self._isEditing = State(initialValue: isEditing)
        self.windowTracker = WindowPositionTracker(note: note)
        isCollapsed = note.isMinimized && !isEditing
        isTextEditorFocused = isEditing
    }
    
    // MARK: - Body
    var body: some View {
        VStack() {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .contextMenu {
            contextMenuContent
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            deleteConfirmationButtons
        }
        .sheet(isPresented: $showHideUntilSheet) {
            HideNoteUntilSheet(note: note)
        }
        .background(Color.fromString($note.color.wrappedValue))
        
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(windowAccessor)
        .frame(width: width, height: height)
        .onHover { handleHover($0) }
        .onChange(of: note.fontSize, initial: false) { updateWindowSize() }
        .onChange(of: note.fontName, initial: false) { updateWindowSize() }
        .onChange(of: note.text, initial: false) { handleTextChange() }
        .onChange(of: isCollapsed, initial: true) { updateWindowSize() }
        .onChange(of: isEditing, initial: true) {old, new in
            if new {
                isCollapsed = false
                
            } else {
                isCollapsed = note.isMinimized
            }
            updateWindowSize()
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var editingView: some View {
        VStack {
            TextEditor(text: $note.text, selection: $selection)
                .scrollContentBackground(.hidden)
                .focused($isTextEditorFocused)
                .onAppear{
                    isCollapsed = false
                    configureEditingMode()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextEditorFocused = true
                    }
                }
                .lineSpacing(note.nsFont.leading)
                .modifier(NoteModifier(note: note))
                .scrollDisabled(true)
                .onDisappear { processNote() }
                .onSubmit { processNote() }
                .onChange(of: note.text) { _, _ in
                    self.updateWindowSize()
                }
                .submitLabel(.done)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onKeyPress { press in
                    if ((press.key == .return && press.modifiers.contains(.command)) || (press.key == .escape)){
                        isEditing = false
                        return .handled
                    }
                    if (press.characters == "=" && press.modifiers.contains(.command)){
                        note.fontSize += 1
                        return .handled
                    }
                    if (press.characters == "-" && press.modifiers.contains(.command)){
                        note.fontSize -= 1
                        return .handled
                    }
  
                    return .ignored
                }
        }
        .padding(.horizontal, -5 + NoteView.horizonalPadding)
        .padding(.top, NoteView.verticalPadding)
    }
    
    
    @ViewBuilder
    private var displayView: some View {
        NoteTextView(note: note, isCollapsed: $isCollapsed)
            .overlay(DraggableArea(isEditing: $isEditing))
            .padding(.horizontal, NoteView.horizonalPadding)
            .padding(.vertical, NoteView.verticalPadding)
            .frame(width: width, height: height, alignment: .topLeading)
        
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            note.isMinimized.toggle()
            isCollapsed = note.isMinimized
        } label: {
            Label(note.isMinimized ? "Maximize" : "Minimize", systemImage: note.isMinimized ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
        }
        
        Button {
            note.trim()
        } label: {
            Label("Trim", systemImage: "square.resize.down")
        }
        
        Divider()
        
        Button {
            note.showOnAllSpaces.toggle()
            AppState.shared.applyShowOnAllSpaces(note: note)
        } label: {
            Label(
                "Show on all spaces",
                systemImage: note.showOnAllSpaces ? "eye.fill" : "eye"
            )
        }
        
        Divider()
        
        Button {
            AppState.shared.copyToClipboard(note)
        } label: {
            Label("Copy to clipboard", systemImage: "doc.on.doc")
        }

        Button {
            AppState.shared.exportNoteToFile(note)
        } label: {
            Label("Export to file…", systemImage: "square.and.arrow.down")
        }
        
        Divider()
        
        Menu("Layout", systemImage: "textformat") {
            LayoutMenu(note: $note)
        }
        
        Divider()

        Button {
            AppState.shared.hideNote(note)
        } label: {
            Label("Hide", systemImage: "eye.slash")
        }

        Button {
            showHideUntilSheet = true
        } label: {
            Label("Hide note until…", systemImage: "calendar.badge.clock")
        }

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
        guard note.isMinimized && maximizeOnHover && !isEditing else { return }
        isCollapsed = !hover
    }
    
    private func handleDelete() {
        if confirmOnDelete {
            showConfirmation = true
        } else {
            self.nsWindow?.close()
            AppState.shared.deleteNote(note)
        }
    }
    
    private func handleTextChange() {
        if !note.isMinimized {
            updateWindowSize()
        }
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
    
    private func updateWindowSize() {
        var newHeight: CGFloat = 0
        var newWidth: CGFloat = 0
       
        let fullSize = note.text.sizeUsingFont(usingFont: note.nsFont)
        if (isCollapsed) {
          
            let collapsedSize = note.text.truncate(NoteView.trimmedLength).sizeUsingFont(usingFont: note.nsFont)
            newHeight = min(fullSize.height, collapsedSize.height)
            newWidth = min(fullSize.width, collapsedSize.width)
        }
        else {
            newWidth = fullSize.width
            newHeight = fullSize.height
        }
        
        
        newHeight += NoteView.verticalPadding * 2
        newWidth += NoteView.horizonalPadding * 2
        
        newWidth = max(20, newWidth)
        
        let newY = height == 0 ? note.y : (note.y! + height - newHeight)
        
        if (isEditing){
//            let wSize = "W".sizeUsingFont(usingFont: note.nsFont)
//            newHeight += wSize.height
            newWidth += 2
        }
        
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
