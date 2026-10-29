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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var note: Note
    @State private var isCollapsed: Bool = false
    @State private var nsWindow: NSWindow?
    /// Key window (focused note); used for a light border when unfocused so edge is visible without shadow.
    @State private var isKeyWindow = true
    @State private var isEditing: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var selection: TextSelection?
    @State private var showConfirmation = false
    @State private var showHideUntilSheet = false
    @State private var showOCRConfirm = false
    @State private var isOCRRunning = false
    @State private var showOCREmptyAlert = false
    @State private var showOCRFailureAlert = false
    @State private var ocrErrorMessage = ""
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
    /// Cached; full markdown parse is too heavy to run from computed properties every layout.
    @State private var markdownHasLinksForCmdTooltip = false

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
        .confirmationDialog(
            "Replace this image note with recognized text? This cannot be undone.",
            isPresented: $showOCRConfirm,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                startOCRFromImage()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("No text recognized", isPresented: $showOCREmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No text could be recognized in this image. Try a clearer or higher-resolution image.")
        }
        .alert("Text recognition failed", isPresented: $showOCRFailureAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ocrErrorMessage)
        }
        .sheet(isPresented: $showHideUntilSheet) {
            HideNoteUntilSheet(notes: contextTargets)
        }
        .background(
            NoteDisplayColors.displayColors(
                storedBgHex: note.color,
                storedFgHex: note.fontColor,
                colorScheme: colorScheme
            ).background
        )
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(windowAccessor)
        .frame(width: resolvedFrameWidth, height: resolvedFrameHeight)
        .overlay {
            if !isKeyWindow {
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .overlay {
            if note.isInbox {
                Rectangle()
                    .strokeBorder(Color.orange.opacity(0.95), lineWidth: 2)
            }
        }
        .overlay {
            if appStateModel.selectedNoteIDs.count > 1,
                appStateModel.selectedNoteIDs.contains(note.persistentModelID)
            {
                Rectangle()
                    .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1)
            }
        }
        .overlay {
            if note.isImageNote && isOCRRunning {
                ZStack {
                    Color.black.opacity(0.22)
                    ProgressView()
                        .controlSize(.regular)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { n in
            guard let w = n.object as? NSWindow, w === nsWindow else { return }
            isKeyWindow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { n in
            guard let w = n.object as? NSWindow, w === nsWindow else { return }
            isKeyWindow = false
        }
        .onAppear {
            if note.isImageNote { isEditing = false }
            updateWindowSize()
            refreshMarkdownLinkPresenceForTooltip()
        }
        .onChange(of: nsWindow) { _, window in
            if let window {
                isKeyWindow = window.isKeyWindow
            }
            guard window != nil else { return }
            syncNoteWindowBackground()
            AppState.shared.applyWindowOpacity(for: note)
            DispatchQueue.main.async { syncLaunchOriginFromWindowOnce() }
        }
        .onChange(of: note.opacity, initial: false) { _, _ in
            AppState.shared.applyWindowOpacity(for: note)
        }
        .onChange(of: colorScheme) { _, _ in
            syncNoteWindowBackground()
        }
        .onChange(of: note.color) { _, _ in
            syncNoteWindowBackground()
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
            refreshMarkdownLinkPresenceForTooltip()
        }
        .onChange(of: isCollapsed, initial: true) {
            updateWindowSize()
            refreshMarkdownLinkPresenceForTooltip()
        }
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
            refreshMarkdownLinkPresenceForTooltip()
        }
    }

    /// Notes affected by context menu actions (multi-selection or single anchor).
    private var contextTargets: [Note] {
        let _ = appStateModel.selectedNoteIDs
        return AppState.shared.notesTargetedForContextMenu(anchorNote: note)
    }

    private var isBulkContextMenu: Bool {
        contextTargets.count > 1
    }

    private var deleteMenuItemTitle: String {
        let n = contextTargets.count
        return n > 1 ? "Delete \(n) notes" : "Delete"
    }

    private var deleteConfirmationTitle: String {
        let _ = appStateModel.selectedNoteIDs
        return AppState.shared.deleteConfirmationMessage(anchorNote: note)
    }

    private var minimizeMaximizeMenuTitle: String {
        if contextTargets.count > 1 {
            return note.isMinimized
                ? "Maximize \(contextTargets.count) notes"
                : "Minimize \(contextTargets.count) notes"
        }
        return note.isMinimized ? "Maximize" : "Minimize"
    }

    private var copyMenuTitle: String {
        contextTargets.count > 1 ? "Copy \(contextTargets.count) notes" : "Copy to clipboard"
    }

    private var shareMenuTitle: String {
        contextTargets.count > 1 ? "Share \(contextTargets.count) notes…" : "Share…"
    }

    private var hideNoteMenuTitle: String {
        contextTargets.count > 1 ? "Hide \(contextTargets.count) notes" : "Hide note"
    }

    private var hideUntilMenuTitle: String {
        contextTargets.count > 1 ? "Hide \(contextTargets.count) notes until" : "Hide until"
    }

    private var shareDisabledForSelection: Bool {
        contextTargets.contains { $0.isImageNote && $0.imageData == nil }
    }

    private var allTargetsPlainTextForTextTools: Bool {
        contextTargets.allSatisfy { !$0.isImageNote && !$0.isMarkdown }
    }

    private var allTargetsNonImageForMarkdownToggle: Bool {
        contextTargets.allSatisfy { !$0.isImageNote }
    }

    /// Shown as ``NSView.toolTip`` on the drag overlay (SwiftUI `help` does not receive hover above that layer).
    private var markdownLinkCommandHelpTooltip: String? {
        guard markdownHasLinksForCmdTooltip else { return nil }
        return "⌘-click to open links"
    }

    private func refreshMarkdownLinkPresenceForTooltip() {
        guard !note.isImageNote, note.isMarkdown, !isCollapsed, !isEditing else {
            markdownHasLinksForCmdTooltip = false
            return
        }
        markdownHasLinksForCmdTooltip = StickNoteMarkdownParser.containsRenderableLink(in: note.text)
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
            .overlay(DraggableArea(isEditing: $isEditing, toolTip: markdownLinkCommandHelpTooltip))
            .padding(.horizontal, NoteView.horizonalPadding)
            .padding(.vertical, NoteView.verticalPadding)
            .frame(width: width, height: height, alignment: .topLeading)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            AppState.shared.copyNotesToClipboard(contextTargets)
        } label: {
            Label(copyMenuTitle, systemImage: "doc.on.doc")
        }

        Button {
            AppState.shared.presentSystemShare(forNotes: contextTargets, anchorWindow: nsWindow)
        } label: {
            Label(shareMenuTitle, systemImage: "square.and.arrow.up")
        }
        .disabled(shareDisabledForSelection)

        if note.isImageNote, note.imageData != nil {
            Button {
                showOCRConfirm = true
            } label: {
                Label("Recognize Text (OCR)…", systemImage: "text.viewfinder")
            }
            .disabled(isBulkContextMenu || isOCRRunning)
        }

        if allTargetsPlainTextForTextTools {
            Menu("Text", systemImage: "text.alignleft") {
                Button("Trim whitespaces") {
                    for n in contextTargets {
                        n.text = n.text.trimmingNoteWhitespace()
                    }
                    updateWindowSize()
                }
                Button("Wrap lines") {
                    for n in contextTargets {
                        n.text = n.text.wrappingLongLinesAtWordBoundaries()
                    }
                    updateWindowSize()
                }
            }
        }

        Button {
            AppState.shared.exportNoteToFile(note)
        } label: {
            Label("Export to file…", systemImage: "square.and.arrow.down")
        }
        .disabled(isBulkContextMenu)

        if AppState.shared.canMergeSelectedNotes() {
            Button {
                AppState.shared.presentMergeSelectedNotesConfirmation()
            } label: {
                Label("Merge selected notes…", systemImage: "arrow.merge")
            }
        }

        Divider()

        if allTargetsNonImageForMarkdownToggle {
            Toggle(
                isOn: Binding(
                    get: {
                        if contextTargets.count <= 1 { return note.isMarkdown }
                        return contextTargets.allSatisfy(\.isMarkdown)
                    },
                    set: { newValue in
                        for n in contextTargets {
                            n.isMarkdown = newValue
                            n.markdownAutoDisabledByUser = !newValue
                        }
                        updateWindowSize()
                    }
                )
            ) {
                Label("Markdown", systemImage: "doc.richtext")
            }
        }

        if !isBulkContextMenu, !note.isImageNote {
            Toggle(
                isOn: Binding(
                    get: { note.isInbox },
                    set: { $0 ? AppState.shared.setInbox(note) : AppState.shared.clearInbox(for: note) }
                )
            ) {
                Label("Inbox", systemImage: "tray")
            }
        }

        Toggle(
            isOn: Binding(
                get: {
                    if contextTargets.count <= 1 { return note.showOnAllSpaces }
                    return contextTargets.allSatisfy(\.showOnAllSpaces)
                },
                set: { newValue in
                    for n in contextTargets {
                        n.showOnAllSpaces = newValue
                        AppState.shared.applyShowOnAllSpaces(note: n)
                    }
                }
            )
        ) {
            Label("Show on all spaces", systemImage: "eye")
        }

        Menu("Layout", systemImage: "textformat") {
            LayoutMenu(note: $note, bulkApplyTargets: isBulkContextMenu ? contextTargets : nil)
        }

        Divider()

        Button {
            let setMinimized = !note.isMinimized
            for n in contextTargets {
                n.isMinimized = setMinimized
            }
            isCollapsed = note.isMinimized
        } label: {
            Label(
                minimizeMaximizeMenuTitle,
                systemImage: note.isMinimized
                    ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"
            )
        }

        Button {
            for n in contextTargets {
                AppState.shared.hideNote(n)
            }
        } label: {
            Label(hideNoteMenuTitle, systemImage: "eye.slash")
        }

        Menu(hideUntilMenuTitle, systemImage: "calendar.badge.clock") {
            Button {
                hideTargets(until: Date.now.addingTimeInterval(30 * 60))
            } label: {
                Label("For 30 Minutes", systemImage: "clock")
            }

            Button {
                hideTargets(until: Date.now.addingTimeInterval(60 * 60))
            } label: {
                Label("For 1 Hour", systemImage: "clock")
            }

            let tomorrow = hideUntilTomorrowMorning()
            Button {
                hideTargets(until: tomorrow)
            } label: {
                Label(
                    "Until Tomorrow, \(tomorrow.formatted(date: .omitted, time: .shortened))",
                    systemImage: "sunrise")
            }

            let nextWeek = hideUntilNextWeekMorning()
            Button {
                hideTargets(until: nextWeek)
            } label: {
                Label(
                    "Until Next Week, \(nextWeek.formatted(.dateTime.weekday(.abbreviated).hour().minute()))",
                    systemImage: "calendar")
            }

            Button {
                showHideUntilSheet = true
            } label: {
                Label("Custom…", systemImage: "calendar.badge.clock")
            }
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
                    appStateModel.areNotesEffectivelyHidden ? "Show notes" : "Hide notes",
                    systemImage: appStateModel.areNotesEffectivelyHidden ? "eye" : "eye.slash"
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

        Divider()

        Button(role: .destructive) {
            handleDelete()
        } label: {
            Label(deleteMenuItemTitle, systemImage: "trash")
        }
    }
    
    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button("Delete", role: .destructive) {
            for n in contextTargets {
                AppState.shared.deleteNote(n)
            }
        }
        Button("Cancel", role: .cancel) {}
    }
    
    private var windowAccessor: some View {
        WindowAccessor { window in
            self.nsWindow = window
            window?.styleMask.remove(.titled)
            window?.backgroundColor = NoteDisplayColors.displayBackgroundNSColor(
                storedBgHex: note.color,
                isDark: colorScheme == .dark
            )
            window?.delegate = self.windowTracker
            window?.level = .floating
        }
    }

    private func syncNoteWindowBackground() {
        nsWindow?.backgroundColor = NoteDisplayColors.displayBackgroundNSColor(
            storedBgHex: note.color,
            isDark: colorScheme == .dark
        )
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
            for n in contextTargets {
                AppState.shared.deleteNote(n)
            }
        }
    }

    private func hideTargets(until date: Date) {
        for n in contextTargets {
            AppState.shared.hideNote(n, hiddenUntil: date)
        }
    }

    private func hideUntilTomorrowMorning() -> Date {
        let cal = Calendar.current
        let now = Date.now
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func hideUntilNextWeekMorning() -> Date {
        let cal = Calendar.current
        let now = Date.now
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 9
        components.minute = 0
        components.second = 0
        return cal.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(7 * 24 * 60 * 60)
    }

    private func startOCRFromImage() {
        guard let data = note.imageData, !data.isEmpty else {
            ocrErrorMessage = ImageOCR.Failure.couldNotCreateCGImage.localizedDescription
            showOCRFailureAlert = true
            return
        }
        isOCRRunning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try ImageOCR.recognizeText(from: data) }
            DispatchQueue.main.async {
                isOCRRunning = false
                switch result {
                case .success(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        showOCREmptyAlert = true
                    } else {
                        applyRecognizedOCRText(text)
                    }
                case .failure(let error):
                    ocrErrorMessage = error.localizedDescription
                    showOCRFailureAlert = true
                }
            }
        }
    }

    private func applyRecognizedOCRText(_ text: String) {
        note.text = text
        note.isImageNote = false
        note.imageData = nil
        note.imageFrameWidth = nil
        note.imageFrameHeight = nil
        note.isMarkdown = false
        note.clearMarkdownDisplayFrame()
        note.applyLikelyMarkdownFlagFromContent()
        note.isMinimized = false
        isCollapsed = false
        isEditing = true
        note.updatedAt = Date.now
        try? AppState.shared.context.save()
        updateWindowSize()
        DispatchQueue.main.async {
            isTextEditorFocused = true
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
        if !isEditing {
            refreshMarkdownLinkPresenceForTooltip()
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
