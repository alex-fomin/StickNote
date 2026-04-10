import AppKit
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

    @Environment(AppStateModel.self) private var appStateModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    @State private var note: Note
    @State private var isCollapsed: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var isEditing: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false
    @State private var showHideUntilSheet = false
    @State private var width: CGFloat
    @State private var height: CGFloat
    /// Cancels stale async markdown measurements when the note changes again before layout finishes.
    @State private var markdownLayoutToken = UUID()
    /// Snapshot when the text editor last appeared; used to run Markdown auto-detect only after real edits.
    @State private var textAtEditSessionStart: String = ""
    /// One-shot: align persisted `note.x` / `note.y` with `NSWindow.frame.origin` after open.
    @State private var didSyncLaunchOriginFromWindow = false

    private let windowTracker: WindowPositionTracker
    
    // MARK: - Initialization
    init(note: Note, isEditing: Bool = false) {
        let collapsed = note.isMinimized && !isEditing
        if note.isMarkdown, !collapsed,
           let sw = note.markdownFrameWidth, let sh = note.markdownFrameHeight,
           sw > 0, sh > 0
        {
            _width = State(initialValue: CGFloat(sw))
            _height = State(initialValue: CGFloat(sh))
        } else {
            _width = State(initialValue: 0)
            _height = State(initialValue: 0)
        }
        self._note = State(initialValue: note)
        self._isEditing = State(initialValue: isEditing)
        self.windowTracker = WindowPositionTracker(note: note)
        isCollapsed = collapsed
        isTextEditorFocused = isEditing
    }
    
    // MARK: - Body
    var body: some View {
        VStack {
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
        .onAppear { updateWindowSize() }
        .onChange(of: nsWindow) { _, window in
            guard window != nil else { return }
            DispatchQueue.main.async { syncLaunchOriginFromWindowOnce() }
        }
        .onHover { handleHover($0) }
        .onChange(of: note.fontSize, initial: false) {
            note.clearMarkdownDisplayFrame()
            updateWindowSize()
        }
        .onChange(of: note.fontName, initial: false) {
            note.clearMarkdownDisplayFrame()
            updateWindowSize()
        }
        .onChange(of: note.text, initial: false) { handleTextChange() }
        .onChange(of: note.isMarkdown, initial: false) { _, new in
            if !new { note.clearMarkdownDisplayFrame() }
            updateWindowSize()
        }
        .onChange(of: isCollapsed, initial: true) { updateWindowSize() }
        .onChange(of: isEditing, initial: true) { old, new in
            if new {
                note.isMinimized = false
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
                    textAtEditSessionStart = note.text
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
        
        Toggle(
            isOn: Binding(
                get: { note.showOnAllSpaces },
                set: { newValue in
                    note.showOnAllSpaces = newValue
                    AppState.shared.applyShowOnAllSpaces(note: note)
                }
            )
        ) {
            Label("Show on all spaces", systemImage: "eye")
        }

        Divider()
        
        Button {
            AppState.shared.copyToClipboard(note)
        } label: {
            Label("Copy to clipboard", systemImage: "doc.on.doc")
        }

        Toggle(
            isOn: Binding(
                get: { note.isMarkdown },
                set: { newValue in
                    note.isMarkdown = newValue
                    note.markdownAutoDisabledByUser = !newValue
                    updateWindowSize()
                }
            )
        ) {
            Label("Markdown", systemImage: "doc.richtext")
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

        Divider()

        Menu("StickNote", systemImage: "note.text") {
            Button("Note list...") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "note-list")
            }
            Button("Show all hidden notes") {
                AppState.shared.requestRevealHiddenNotesInList()
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "note-list")
            }
            Button {
                AppState.shared.toggleNotesVisibility()
            } label: {
                Label(
                    appStateModel.isNotesHidden ? "Show notes" : "Hide notes",
                    systemImage: appStateModel.isNotesHidden ? "eye" : "eye.slash"
                )
            }
            Divider()
            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
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
        if note.isMarkdown {
            note.clearMarkdownDisplayFrame()
        }
        if !note.isMinimized {
            updateWindowSize()
        }
    }
    
    private func processNote() {
        let priorForComparison = textAtEditSessionStart.removeTrailingEmptyLines()
        note.text = note.text.removeTrailingEmptyLines()
        if note.text.isEmpty {
            AppState.shared.deleteNote(self.note, forceDelete: true)
            nsWindow?.close()
        } else {
            let textChangedThisSession = note.text != priorForComparison
            if textChangedThisSession {
                note.applyLikelyMarkdownFlagFromContent()
            }
            if maximizeOnEdit {
                note.isMinimized = false
            }
        }
    }

    private func syncLaunchOriginFromWindowOnce() {
        guard !didSyncLaunchOriginFromWindow, let w = nsWindow else { return }
        didSyncLaunchOriginFromWindow = true
        note.x = w.frame.origin.x
        note.y = w.frame.origin.y
    }

    private func updateWindowSize() {
        if note.isMarkdown, !isCollapsed, !isEditing,
           let sw = note.markdownFrameWidth, let sh = note.markdownFrameHeight,
           sw > 0, sh > 0
        {
            applyPersistedMarkdownFrame(frameWidth: CGFloat(sw), frameHeight: CGFloat(sh))
            return
        }

        // Rendered markdown size can differ a lot from plain `sizeUsingFont` (headings, lists, code).
        // Whenever we show markdown without a stored frame, measure off-screen layout instead of plain text.
        if note.isMarkdown, !isCollapsed, !isEditing {
            refineMarkdownFrameAfterEditing()
            return
        }

        let fullSize = note.text.sizeUsingFont(usingFont: note.nsFont)
        applyWindowFrame(fullContentSize: fullSize, persistMarkdownFrame: false)
    }

    /// Accurate markdown layout from an off-screen render; run only after editing so activating the note does not resize it.
    private func refineMarkdownFrameAfterEditing() {
        let token = UUID()
        markdownLayoutToken = token
        // Do not cap by plain-text width: markdown blocks can be wider or narrower than `sizeUsingFont`.
        MarkdownDisplayMeasurer.shared.measure(note: note, contentMaxWidth: nil) { measured in
            guard self.markdownLayoutToken == token else { return }
            self.applyWindowFrame(fullContentSize: measured, persistMarkdownFrame: true)
        }
    }

    /// Height to use when anchoring the window top edge: must match ``note.y``'s source (``NSWindow.frame``), not stale SwiftUI state.
    private func anchorWindowHeightForResize() -> CGFloat {
        if let w = nsWindow { return w.frame.height }
        return height
    }

    /// Restores a previously saved markdown window size (full frame, including padding).
    private func applyPersistedMarkdownFrame(frameWidth: CGFloat, frameHeight: CGFloat) {
        let newWidth = max(20, frameWidth)
        let newHeight = frameHeight
        let oldH = anchorWindowHeightForResize()
        let newY = height == 0 ? note.y : (note.y! + oldH - newHeight)
        width = newWidth
        height = newHeight
        note.y = newY
    }

    /// `fullContentSize` is the text measurement only (before note padding).
    private func applyWindowFrame(fullContentSize: CGSize, persistMarkdownFrame: Bool) {
        let fullSize: CGSize
        if isCollapsed {
            let collapsedSize = note.text.truncate(NoteView.trimmedLength).sizeUsingFont(usingFont: note.nsFont)
            fullSize = CGSize(
                width: min(fullContentSize.width, collapsedSize.width),
                height: min(fullContentSize.height, collapsedSize.height)
            )
        } else {
            fullSize = fullContentSize
        }

        var newWidth = fullSize.width + NoteView.horizonalPadding * 2
        var newHeight = fullSize.height + NoteView.verticalPadding * 2
        newWidth = max(20, newWidth)

        if isEditing {
            newWidth += 2
        }

        let oldH = anchorWindowHeightForResize()
        let newY = height == 0 ? note.y : (note.y! + oldH - newHeight)

        width = newWidth
        height = newHeight
        note.y = newY

        if persistMarkdownFrame, note.isMarkdown, !isCollapsed, !isEditing {
            note.markdownFrameWidth = Double(newWidth)
            note.markdownFrameHeight = Double(newHeight)
        }
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
