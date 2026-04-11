import AppKit
import Defaults
import SwiftData
import SwiftUI

struct NoteView: View {
    static let horizonalPadding: CGFloat = 2
    static let verticalPadding: CGFloat = 2
    static let trimmedLength = 4
    /// Icon + spacing beyond truncated text width for minimized image strip (see ``imageCollapsedStrip``).
    static let imageCollapsedStripExtraWidth: CGFloat = 6 + 18

    // MARK: - Properties
    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.maximizeOnHover) var maximizeOnHover

    @Environment(AppStateModel.self) private var appStateModel
    @Environment(\.modelContext) private var modelContext
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
    /// Skips ``resizeImageNoteWindowForFontChange`` / markdown resize while applying Cmd+0 default zoom.
    @State private var isApplyingZoomReset = false

    private let windowTracker: WindowPositionTracker

    private var resolvedFrameWidth: CGFloat {
        if note.isImageNote {
            if isCollapsed { return max(20, width) }
            if let w = note.imageFrameWidth, w > 0 { return CGFloat(w) }
        }
        return width
    }

    private var resolvedFrameHeight: CGFloat {
        if note.isImageNote {
            if isCollapsed { return max(20, height) }
            if let h = note.imageFrameHeight, h > 0 { return CGFloat(h) }
        }
        return height
    }

    // MARK: - Initialization
    init(note: Note, isEditing: Bool = false) {
        let collapsed = note.isMinimized && !isEditing
        if note.isImageNote, let data = note.imageData, !data.isEmpty {
            if collapsed {
                _width = State(initialValue: 0)
                _height = State(initialValue: 0)
            } else if let sw = note.imageFrameWidth, let sh = note.imageFrameHeight, sw > 0, sh > 0 {
                _width = State(initialValue: CGFloat(sw))
                _height = State(initialValue: CGFloat(sh))
            } else if let img = NSImage(data: data) {
                let maxDim: CGFloat = 600
                let intrinsic = img.size
                let longest = max(intrinsic.width, intrinsic.height, 1)
                let s = min(1, maxDim / longest)
                let contentW = intrinsic.width * s + Self.horizonalPadding * 2
                let contentH = intrinsic.height * s + Self.verticalPadding * 2
                _width = State(initialValue: max(20, contentW))
                _height = State(initialValue: max(20, contentH))
            } else {
                _width = State(initialValue: 200)
                _height = State(initialValue: 200)
            }
        } else if note.isMarkdown, !collapsed,
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
        self._isEditing = State(initialValue: isEditing && !note.isImageNote)
        self.windowTracker = WindowPositionTracker(note: note)
        isCollapsed = collapsed
        isTextEditorFocused = isEditing && !note.isImageNote
    }
    
    // MARK: - Body
    var body: some View {
        VStack {
            if note.isImageNote {
                imageDisplayView
            } else if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .onKeyPress { press in
            if press.characters == "0" && press.modifiers.contains(.command) {
                resetZoomToDefault()
                return .handled
            }
            return .ignored
        }
        .contextMenu {
            contextMenuContent
        }
        .confirmationDialog(
            deleteConfirmationTitle,
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
        .frame(width: resolvedFrameWidth, height: resolvedFrameHeight)
        .onAppear {
            if note.isImageNote { isEditing = false }
            updateWindowSize()
        }
        .onChange(of: nsWindow) { _, window in
            guard window != nil else { return }
            DispatchQueue.main.async { syncLaunchOriginFromWindowOnce() }
        }
        .onHover { handleHover($0) }
        .onReceive(NotificationCenter.default.publisher(for: .stickNoteResetZoom)) { notification in
            guard let n = notification.object as? Note, n.id == note.id else { return }
            resetZoomToDefault()
        }
        .onChange(of: note.fontSize, initial: false) { oldFont, newFont in
            if isApplyingZoomReset { return }
            if note.isImageNote {
                resizeImageNoteWindowForFontChange(from: oldFont, to: newFont)
                return
            }
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
        .onChange(of: note.isMinimized, initial: false) { _, new in
            guard !isEditing else { return }
            isCollapsed = new
        }
        .onChange(of: isEditing, initial: true) { old, new in
            if note.isImageNote {
                isEditing = false
                return
            }
            if new {
                note.isMinimized = false
                isCollapsed = false
            } else {
                isCollapsed = note.isMinimized
            }
            updateWindowSize()
        }
    }

    private var deleteConfirmationTitle: String {
        if note.isImageNote {
            return "Delete this image note?"
        }
        return #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#
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
                    if press.characters == "0" && press.modifiers.contains(.command) {
                        resetZoomToDefault()
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
    private var imageDisplayView: some View {
        Group {
            if isCollapsed {
                imageCollapsedStrip
            } else {
                NoteImageDisplay(imageData: note.imageData)
            }
        }
        .overlay(
            DraggableArea(
                isEditing: $isEditing,
                allowsEditOnDoubleClick: false,
                onDoubleClick: {
                    guard isCollapsed else { return }
                    note.isMinimized = false
                    isCollapsed = false
                }
            )
        )
        .padding(.horizontal, NoteView.horizonalPadding)
        .padding(.vertical, NoteView.verticalPadding)
        .frame(width: resolvedFrameWidth, height: resolvedFrameHeight, alignment: .topLeading)
    }

    private var imageCollapsedStrip: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            Text(note.text.truncate(NoteView.trimmedLength))
                .lineLimit(1)
        }
        .modifier(NoteModifier(note: note))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

        if !note.isImageNote {
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
                AppState.shared.presentSettingsWindow()
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
        guard !note.isImageNote else { return }
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

    /// Cmd+0: text notes use the matching persisted ``NoteLayout`` font size; image notes use default layout size and snap window to intrinsic image size.
    private func resetZoomToDefault() {
        let resetFontSize: CGFloat =
            note.isImageNote
            ? NoteLayout.defaultLayout.fontSize
            : layoutFontSizeFromMatchingNoteLayout()
        isApplyingZoomReset = true
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                isApplyingZoomReset = false
            }
        }

        if note.isImageNote {
            note.isMinimized = false
            isCollapsed = false
            note.imageFrameWidth = nil
            note.imageFrameHeight = nil
            applyImageNoteWindowFrame()
            if !isCollapsed {
                note.imageFrameWidth = Double(width)
                note.imageFrameHeight = Double(height)
            }
            note.fontSize = resetFontSize
            note.updatedAt = Date.now
            try? AppState.shared.context.save()
        } else {
            note.fontSize = resetFontSize
            note.clearMarkdownDisplayFrame()
            updateWindowSize()
            note.updatedAt = Date.now
            try? AppState.shared.context.save()
        }
    }

    /// Font size from the ``NoteLayout`` that matches this note’s color, font name, and font color (ignores zoomed ``Note/fontSize``).
    private func layoutFontSizeFromMatchingNoteLayout() -> CGFloat {
        let descriptor = FetchDescriptor<NoteLayout>()
        guard let layouts = try? modelContext.fetch(descriptor) else {
            return NoteLayout.defaultLayout.fontSize
        }
        return layouts.first { layout in
            layout.color == note.color
                && layout.fontColor == note.fontColor
                && layout.fontName == note.fontName
        }?.fontSize ?? NoteLayout.defaultLayout.fontSize
    }

    /// Cmd+/Cmd- scales window dimensions by `newFont/oldFont` and keeps the top edge fixed; ``Note/imageData`` is unchanged.
    private func resizeImageNoteWindowForFontChange(from oldFont: CGFloat, to newFont: CGFloat) {
        guard note.isImageNote, oldFont > 0, newFont > 0, oldFont != newFont else { return }
        let ratio = newFont / oldFont

        let curW = resolvedFrameWidth
        let curH = resolvedFrameHeight
        let newW = max(20, curW * ratio)
        let newH = max(20, curH * ratio)

        let oldH = anchorWindowHeightForResize()
        let newY = height == 0 ? note.y : (note.y! + oldH - newH)

        width = newW
        height = newH
        if !isCollapsed {
            note.imageFrameWidth = Double(newW)
            note.imageFrameHeight = Double(newH)
        }
        note.y = newY
        note.updatedAt = Date.now

        if let win = nsWindow {
            var f = win.frame
            let top = f.maxY
            f.size.width = newW
            f.size.height = newH
            f.origin.y = top - newH
            win.setFrame(f, display: true)
        }

        try? AppState.shared.context.save()
    }

    private func expandedImageContentFrameSize() -> CGSize {
        if let iw = note.imageFrameWidth, let ih = note.imageFrameHeight, iw > 0, ih > 0 {
            return CGSize(width: CGFloat(iw), height: CGFloat(ih))
        }
        guard let data = note.imageData, let img = NSImage(data: data) else {
            return CGSize(width: 200, height: 200)
        }
        let maxDim: CGFloat = 600
        let intrinsic = img.size
        let longest = max(intrinsic.width, intrinsic.height, 1)
        let s = min(1, maxDim / longest)
        let contentW = intrinsic.width * s + Self.horizonalPadding * 2
        let contentH = intrinsic.height * s + Self.verticalPadding * 2
        return CGSize(width: max(20, contentW), height: max(20, contentH))
    }

    private func applyImageNoteFrame(width newW: CGFloat, height newH: CGFloat) {
        let oldH = anchorWindowHeightForResize()
        let newY = height == 0 ? note.y : (note.y! + oldH - newH)

        width = newW
        height = newH
        note.y = newY
        note.updatedAt = Date.now

        if let win = nsWindow {
            var f = win.frame
            let top = f.maxY
            f.size.width = newW
            f.size.height = newH
            f.origin.y = top - newH
            win.setFrame(f, display: true)
        }

        try? AppState.shared.context.save()
    }

    /// Sizes the image note window: a strip when minimized; full image when maximized. Persists dimensions via ``WindowPositionTracker`` only while maximized.
    private func applyImageNoteWindowFrame() {
        if isCollapsed {
            let textForSize = note.text.truncate(NoteView.trimmedLength)
            let fs = textForSize.sizeUsingFont(usingFont: note.nsFont)
            let newW = max(
                20,
                fs.width + Self.imageCollapsedStripExtraWidth + NoteView.horizonalPadding * 2)
            let newH = max(20, fs.height + NoteView.verticalPadding * 2)
            applyImageNoteFrame(width: newW, height: newH)
            return
        }

        let full = expandedImageContentFrameSize()
        applyImageNoteFrame(width: full.width, height: full.height)
    }

    private func updateWindowSize() {
        if note.isImageNote {
            applyImageNoteWindowFrame()
            return
        }
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
