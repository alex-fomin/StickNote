import AppKit
import Defaults
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

final class AppState {

    static let shared: AppState = AppState()
    @Default(.deleteToTrashBin) var deleteToTrashBin
    @Default(.trimAfterPaste) var trimAfterPaste
    @Default(.wrapLongLinesAfterPaste) var wrapLongLinesAfterPaste

    var sharedModelContainer: ModelContainer
    var context: ModelContext

    var windows:[NoteWindow] = []

    private var scheduledUnhideTimer: Timer?

    private init() {
        self.sharedModelContainer = {
            let schema = Schema([
                Note.self,
                NoteLayout.self,
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: false)

            do {
                return try ModelContainer(
                    for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        self.context = ModelContext(self.sharedModelContainer)

        let layouts = try? self.context.fetch<Category>(FetchDescriptor<NoteLayout>())
        if layouts == nil || layouts?.isEmpty == true {
            let defaultLayouts = NoteLayout.defaultLayouts()

            for defaultLayout in defaultLayouts {
                self.context.insert(defaultLayout)
            }

            try? self.context.save()
        }

        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            AppState.shared.processDueScheduledUnhides()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        scheduledUnhideTimer = timer
    }

    func getDefaultLayout() -> NoteLayout {
        return
            (try? self.context.fetch<Category>(
                FetchDescriptor<NoteLayout>(predicate: #Predicate { $0.isDefault == true })))?.first
            ?? NoteLayout.defaultLayout
    }

    func openNewNote() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.openNewNote() }
            return
        }
        let note = Note(layout: getDefaultLayout())
        note.showOnAllSpaces = Defaults[.showOnAllSpaces]
        self.context.insert(note)

        self.openNote(note, isEditing: true)
        replaceSelection(with: note)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openNewNoteFromClipboard() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.openNewNoteFromClipboard() }
            return
        }
        if let pngData = NoteClipboardImage.exportPastedImageToPNGData() {
            let note = Note(layout: getDefaultLayout(), text: "Image")
            note.isImageNote = true
            note.imageData = pngData
            note.isMarkdown = false
            note.showOnAllSpaces = Defaults[.showOnAllSpaces]
            context.insert(note)
            openNote(note, isEditing: false)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let text = NSPasteboard.general.string(forType: .string) {
            if !text.isEmpty {
                var content = text
                if trimAfterPaste {
                    content = content.trimmingNoteWhitespace()
                }
                if wrapLongLinesAfterPaste {
                    content = content.wrappingLongLinesAtWordBoundaries()
                }
                let note = Note(layout: getDefaultLayout(), text: content)
                note.showOnAllSpaces = Defaults[.showOnAllSpaces]
                self.context.insert(note)
                
                self.openNote(note, isEditing: false)
            }
        }
    }

    /// Appends clipboard string to the most recently updated non-image note (new line).
    /// If that note is hidden, creates a new note with the clipboard content instead.
    func appendClipboardToLatestEditedNote() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }

        var content = text
        if trimAfterPaste {
            content = content.trimmingNoteWhitespace()
        }
        if wrapLongLinesAfterPaste {
            content = content.wrappingLongLinesAtWordBoundaries()
        }
        guard !content.isEmpty else { return }

        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.isInTrashBin == false && $0.isImageNote == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let note = try? context.fetch(descriptor).first else { return }

        if note.isHidden {
            let newNote = Note(layout: getDefaultLayout(), text: content)
            newNote.showOnAllSpaces = Defaults[.showOnAllSpaces]
            context.insert(newNote)
            openNote(newNote, isEditing: false)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let existing = note.text
        if existing.isEmpty {
            note.text = content
        } else if existing.hasSuffix("\n") {
            note.text = existing + content
        } else {
            note.text = existing + "\n" + content
        }
        note.clearMarkdownDisplayFrame()
        note.applyLikelyMarkdownFlagFromContent()
        try? context.save()

        openNote(note, isEditing: false)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openNote(_ note: Note, isEditing: Bool) {
        let effectiveEditing = isEditing && !note.isImageNote
        if let existing = note.window {
            existing.orderFront(nil)
            if effectiveEditing {
                NSApplication.shared.activate(ignoringOtherApps: true)
                existing.makeKey()
            }
            return
        }

        let contentRect = getContentRectFromNote(note, isEditing: effectiveEditing)

        note.x = contentRect.minX
        note.y = contentRect.minY

        var styleMask: NSWindow.StyleMask = [.titled]
        if note.isImageNote {
            styleMask.insert(.resizable)
        }
        let window = NoteWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: true
        )
        window.note = note
        note.window = window

        let contentView = NoteView(note: note, isEditing: effectiveEditing)
            .environment(\.modelContext, self.sharedModelContainer.mainContext)
            .environment(AppState.shared.model)

        window.contentView = NSHostingView(rootView: contentView)

        window.level = .floating
        window.hasShadow = effectiveEditing
        window.isReleasedWhenClosed = false

        applyShowOnAllSpaces(note: note)

        window.orderFront(nil)
        if effectiveEditing {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKey()
        }

        window.styleMask.remove(.titled)
        if note.isImageNote {
            window.styleMask.insert(.resizable)
        }

        try? context.save()
        self.updateNotesCount()
        self.windows.append(window);

        applyFullscreenSuppressionToOpenWindowsIfNeeded()
    }

    /// Initial window frame. Uses saved markdown size or measured text instead of a 10×10 stub
    /// so the first layout matches persisted position (avoids a large height jump on launch).
    private func getContentRectFromNote(_ note: Note, isEditing: Bool) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero

        let x = note.x ?? (screenFrame.midX - 500 + CGFloat(self.windows.count) * 20)
        let y = note.y ?? (screenFrame.midY + 450 - CGFloat(self.windows.count) * 20)

        let collapsedDisplay = note.isMinimized && !isEditing
        let padW = NoteView.horizonalPadding * 2
        let padV = NoteView.verticalPadding * 2

        var cw: CGFloat = 10
        var ch: CGFloat = 10

        if note.isImageNote, note.imageData != nil {
            if collapsedDisplay {
                let textForSize = note.text.truncate(NoteView.trimmedLength)
                let fs = textForSize.sizeUsingFont(usingFont: note.nsFont)
                cw = max(20, fs.width + NoteView.imageCollapsedStripExtraWidth + padW)
                ch = max(20, fs.height + padV)
                return NSRect(x: x, y: y, width: cw, height: ch)
            }
            if let mw = note.imageFrameWidth, let mh = note.imageFrameHeight, mw > 0, mh > 0 {
                cw = CGFloat(mw)
                ch = CGFloat(mh)
            } else if let img = NSImage(data: note.imageData!) {
                let maxDim: CGFloat = 600
                let intrinsic = img.size
                let longest = max(intrinsic.width, intrinsic.height, 1)
                let scale = min(1, maxDim / longest)
                cw = max(20, intrinsic.width * scale + padW)
                ch = max(20, intrinsic.height * scale + padV)
            } else {
                cw = 200
                ch = 200
            }
            return NSRect(x: x, y: y, width: cw, height: ch)
        }

        if note.isMarkdown, !collapsedDisplay,
           let mw = note.markdownFrameWidth, let mh = note.markdownFrameHeight,
           mw > 0, mh > 0
        {
            cw = CGFloat(mw)
            ch = CGFloat(mh)
        } else if !note.text.isEmpty {
            let textForSize =
                collapsedDisplay
                ? note.text.truncate(NoteView.trimmedLength)
                : note.text
            let fs = textForSize.sizeUsingFont(usingFont: note.nsFont)
            var w = fs.width + padW
            var h = fs.height + padV
            if isEditing { w += 2 }
            cw = max(20, w)
            ch = max(20, h)
        }

        return NSRect(x: x, y: y, width: cw, height: ch)
    }

    func processDueScheduledUnhides() {
        let now = Date.now
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.isHidden == true })
        guard let hidden = try? context.fetch(descriptor) else { return }
        var changed = false
        for note in hidden {
            guard note.isInTrashBin == false, let until = note.hiddenUntil, until <= now else { continue }
            note.isHidden = false
            note.hiddenUntil = nil
            note.updatedAt = now
            changed = true
            if !note.text.isEmpty || (note.isImageNote && note.imageData != nil) {
                openNote(note, isEditing: false)
            }
        }
        if changed {
            try? context.save()
            updateNotesCount()
        }
    }

    func openAllNotes() {
        let notes: [Note]? = try? self.context.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.isInTrashBin == false && $0.isHidden == false }))
        
        if let notes {
            for note in notes {
                if note.text.isEmpty && !(note.isImageNote && note.imageData != nil) {
                    self.deleteNote(note, forceDelete: true)
                } else {
                    self.openNote(note, isEditing: false)
                }
            }
        }
    }

    func deleteNote(_ note: Note, forceDelete: Bool = false) {
        removeNoteFromSelection(note)
        if let window = note.window {
            note.window = nil
            window.close()
            self.windows.removeAll { $0 === window }
        }

        if forceDelete || !deleteToTrashBin {
            let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
            NoteClipboardImage.deleteStoredImagesIfOnlyReferencedByDeletedNote(
                deletedNote: note,
                allNotes: allNotes
            )
            self.context.delete(note)
        } else {
            note.isInTrashBin = true
            note.hiddenUntil = nil
            note.updatedAt = Date.now
        }
        try? self.context.save()
        self.updateNotesCount()
    }

    func updateNotesCount() {
        model.notesCount = try! self.context.fetchCount(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.isInTrashBin == false && $0.isHidden == false }))
    }

    func hideNote(_ note: Note, hiddenUntil until: Date? = nil) {
        if let until, until <= Date.now {
            return
        }
        removeNoteFromSelection(note)
        let noteId = note.persistentModelID
        if let window = note.window ?? windows.first(where: { $0.note?.persistentModelID == noteId }) {
            note.window = nil
            window.close()
            self.windows.removeAll { $0 === window }
        }
        note.isHidden = true
        note.hiddenUntil = until
        note.updatedAt = Date.now
        try? context.save()
        updateNotesCount()
    }

    func unhideNote(_ note: Note) {
        note.isHidden = false
        note.hiddenUntil = nil
        note.updatedAt = Date.now
        try? context.save()
        updateNotesCount()
        openNote(note, isEditing: false)
    }

    func requestRevealHiddenNotesInList() {
        model.noteListRevealHiddenToken += 1
        // Menu bar and the note list live in different scenes; Observation may not refresh
        // the list window. A main-queue notification reliably switches the sidebar selection.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .stickNoteRevealHiddenNotesInList, object: nil)
        }
    }
    
    @MainActor
    func copyToClipboard(_ note: Note) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if note.isImageNote, let data = note.imageData {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(UTType.png.identifier))
            if let img = NSImage(data: data), let tiff = img.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            return
        }
        if note.isMarkdown {
            MarkdownClipboard.populatePasteboard(pasteboard, note: note)
        } else {
            pasteboard.setString(note.text, forType: .string)
        }
    }

    /// Concatenates several notes as plain text (image notes become a short placeholder line).
    @MainActor
    func copyNotesToClipboard(_ notes: [Note]) {
        guard let first = notes.first else { return }
        if notes.count == 1 {
            copyToClipboard(first)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let separator = "\n\n────────\n\n"
        let combined = notes.map { n -> String in
            if n.isImageNote {
                let label = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return label.isEmpty ? "[Image]" : "[Image: \(label)]"
            }
            return n.text
        }.joined(separator: separator)
        pasteboard.setString(combined, forType: .string)
    }

    @MainActor
    func presentSystemShare(for note: Note, anchorWindow: NSWindow? = nil) {
        let items: [Any]
        if note.isImageNote {
            guard let data = note.imageData, let image = NSImage(data: data) else { return }
            items = [image]
        } else {
            items = [note.text as NSString]
        }

        let window = anchorWindow ?? NSApp.keyWindow
        guard let view = window?.contentView else { return }

        let rect = NSRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    @MainActor
    func presentSystemShare(forNotes notes: [Note], anchorWindow: NSWindow? = nil) {
        guard let first = notes.first else { return }
        if notes.count == 1 {
            presentSystemShare(for: first, anchorWindow: anchorWindow)
            return
        }
        var items: [Any] = []
        for n in notes {
            if n.isImageNote, let data = n.imageData, let image = NSImage(data: data) {
                items.append(image)
            } else {
                items.append(n.text as NSString)
            }
        }
        let window = anchorWindow ?? NSApp.keyWindow
        guard let view = window?.contentView else { return }
        let rect = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    func exportNoteToFile(_ note: Note) {
        if note.isImageNote, let data = note.imageData {
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                panel.canCreateDirectories = true
                panel.title = "Export Image"
                panel.nameFieldStringValue = "Image.png"
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    do {
                        try data.write(to: url, options: .atomic)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Couldn’t save the file."
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
            return
        }
        let text = note.text
        let isMarkdown = note.isMarkdown
        let defaultName = Self.suggestedExportFilename(for: text, isMarkdown: isMarkdown)
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            if isMarkdown, let mdType = UTType(filenameExtension: "md") {
                panel.allowedContentTypes = [mdType, .plainText]
            } else {
                panel.allowedContentTypes = [.plainText]
            }
            panel.canCreateDirectories = true
            panel.title = "Export Note"
            panel.nameFieldStringValue = defaultName
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Couldn’t save the file."
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private static func suggestedExportFilename(for text: String, isMarkdown: Bool) -> String {
        let firstLine =
            text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? "Note"
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        var base = trimmed.isEmpty ? "Note" : String(trimmed.prefix(80))
        for ch in ["/", ":", "\0"] {
            base = base.replacingOccurrences(of: ch, with: "-")
        }
        base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "Note" }
        let ext = isMarkdown ? "md" : "txt"
        let lower = base.lowercased()
        if lower.hasSuffix(".\(ext)") {
            return base
        }
        if lower.hasSuffix(".txt") {
            base = String(base.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasSuffix(".md") {
            base = String(base.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if base.isEmpty { base = "Note" }
        return "\(base).\(ext)"
    }

    func toggleNotesVisibility() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.toggleNotesVisibility() }
            return
        }
        let effectivelyHidden = model.areNotesEffectivelyHidden
        if !effectivelyHidden {
            clearSelection()
        }
        for window in self.windows {
            if effectivelyHidden {
                window.orderFront(nil)
            } else {
                window.orderOut(nil)
            }
        }
        model.isNotesHidden = effectivelyHidden ? false : true
        model.suppressedByFullscreen = false
    }

    func updateFullscreenSuppression() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.updateFullscreenSuppression() }
            return
        }
        guard Defaults[.hideNotesWhenFullscreenApp] else {
            restoreFromFullscreenSuppression()
            return
        }
        if FullscreenAppDetector.isActiveFullscreenAppPresent() {
            suppressForFullscreenIfNeeded()
        } else {
            restoreFromFullscreenSuppression()
        }
    }

    private func suppressForFullscreenIfNeeded() {
        guard !model.isNotesHidden else { return }
        guard !model.suppressedByFullscreen else { return }
        for window in windows {
            window.orderOut(nil)
        }
        model.suppressedByFullscreen = true
    }

    private func restoreFromFullscreenSuppression() {
        guard model.suppressedByFullscreen else { return }
        model.suppressedByFullscreen = false
        if !model.isNotesHidden {
            for window in windows {
                window.orderFront(nil)
            }
        }
    }

    private func applyFullscreenSuppressionToOpenWindowsIfNeeded() {
        guard Defaults[.hideNotesWhenFullscreenApp],
              FullscreenAppDetector.isActiveFullscreenAppPresent(),
              !model.isNotesHidden
        else { return }
        for window in windows {
            window.orderOut(nil)
        }
        model.suppressedByFullscreen = true
    }

    func applyShowOnAllSpaces(note: Note) {
        guard let nsWindow = note.window else { return }
        if note.showOnAllSpaces {
            nsWindow.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            nsWindow.collectionBehavior.remove(.canJoinAllSpaces)
        }
        nsWindow.update()
    }

    func emptyTrashBin() {
        let notes = try? self.context.fetch<Note>(
            FetchDescriptor<Note>(predicate: #Predicate { $0.isInTrashBin == true }))

        if let notes {
            for note in notes {
                self.deleteNote(note, forceDelete: true)
            }
        }
    }

    /// Posts ``Notification/Name/stickNoteResetZoom`` so ``NoteView`` can reset font and image scale (Cmd+0).
    func postResetZoom(for note: Note) {
        NotificationCenter.default.post(name: .stickNoteResetZoom, object: note)
    }

    func presentSettingsWindow() {
        SettingsWindowController.shared.present()
    }

    // MARK: - Multi-select (floating note windows)

    func clearSelection() {
        model.selectedNoteIDs = []
    }

    func removeNoteFromSelection(_ note: Note) {
        let id = note.persistentModelID
        if model.selectedNoteIDs.contains(id) {
            model.selectedNoteIDs = model.selectedNoteIDs.subtracting([id])
        }
    }

    /// Drops IDs that no longer have an open note window.
    func pruneSelectionForClosedWindows() {
        let openIDs = Set(windows.compactMap { $0.note?.persistentModelID })
        model.selectedNoteIDs = model.selectedNoteIDs.intersection(openIDs)
    }

    /// When several floating notes are selected and the user acts on one of them, menu commands apply to every selected open note. Otherwise only `anchorNote`.
    func notesTargetedForContextMenu(anchorNote: Note) -> [Note] {
        pruneSelectionForClosedWindows()
        let ordered = orderedSelectedNotesFrontToBack()
        guard ordered.count > 1,
            model.selectedNoteIDs.contains(anchorNote.persistentModelID)
        else {
            return [anchorNote]
        }
        return ordered
    }

    func deleteConfirmationMessage(anchorNote: Note) -> String {
        let targets = notesTargetedForContextMenu(anchorNote: anchorNote)
        if targets.count > 1 {
            return "Are you sure you want to delete \(targets.count) notes?"
        }
        if anchorNote.isImageNote {
            return "Delete this image note?"
        }
        return #"Are you sure you want to delete "\#(anchorNote.text.truncate(15))"?"#
    }

    func replaceSelection(with note: Note) {
        model.selectedNoteIDs = [note.persistentModelID]
    }

    func toggleSelection(for note: Note) {
        let id = note.persistentModelID
        if model.selectedNoteIDs.contains(id) {
            model.selectedNoteIDs = model.selectedNoteIDs.subtracting([id])
        } else {
            model.selectedNoteIDs = model.selectedNoteIDs.union([id])
        }
    }

    /// Selected notes with open windows, **front-to-back** (first = frontmost).
    private func orderedSelectedNotesFrontToBack() -> [Note] {
        pruneSelectionForClosedWindows()
        let idSet = model.selectedNoteIDs
        var ordered: [Note] = []
        for w in NSApp.windows.reversed() {
            guard let nw = w as? NoteWindow, let n = nw.note, idSet.contains(n.persistentModelID) else {
                continue
            }
            ordered.append(n)
        }
        return ordered
    }

    private func mergeSurvivorNote(orderedFrontToBack: [Note]) -> Note? {
        guard let first = orderedFrontToBack.first else { return nil }
        if let keyWin = NSApp.keyWindow as? NoteWindow,
            let keyNote = keyWin.note,
            orderedFrontToBack.contains(where: { $0.persistentModelID == keyNote.persistentModelID })
        {
            return keyNote
        }
        return first
    }

    func canMergeSelectedNotes() -> Bool {
        pruneSelectionForClosedWindows()
        let ordered = orderedSelectedNotesFrontToBack()
        guard ordered.count >= 2 else { return false }
        return !ordered.contains(where: { $0.isImageNote })
    }

    /// Presents a confirmation alert, then merges selected windows into one note.
    func presentMergeSelectedNotesConfirmation() {
        pruneSelectionForClosedWindows()
        guard canMergeSelectedNotes() else { return }

        let ordered = orderedSelectedNotesFrontToBack()
        guard ordered.count >= 2, let survivor = mergeSurvivorNote(orderedFrontToBack: ordered) else {
            return
        }
        let others = ordered.filter { $0.persistentModelID != survivor.persistentModelID }

        let alert = NSAlert()
        alert.messageText = "Merge \(ordered.count) notes into one?"
        alert.informativeText =
            "Text from the other notes will be appended to the note you keep. Other notes will be moved to the Trash or deleted permanently, depending on your settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Cancel")
        let choice = alert.runModal()
        guard choice == .alertFirstButtonReturn else { return }

        mergeNotes(survivor: survivor, sourcesToAppend: others)
    }

    /// Concatenates `sourcesToAppend` onto `survivor`, then deletes each source via ``deleteNote``.
    func mergeNotes(survivor: Note, sourcesToAppend: [Note]) {
        guard !sourcesToAppend.isEmpty else { return }
        var combined = survivor.text
        for s in sourcesToAppend {
            combined += "\n\n" + s.text
        }
        survivor.text = combined
        survivor.applyLikelyMarkdownFlagFromContent()
        for s in sourcesToAppend {
            deleteNote(s)
        }
        clearSelection()
        survivor.window?.orderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var model: AppStateModel = AppStateModel()
}

extension Notification.Name {
    /// Posted for Cmd+0; ``object`` is the ``Note`` to reset zoom for.
    static let stickNoteResetZoom = Notification.Name("StickNote.resetZoom")
}

@Observable class AppStateModel: ObservableObject {
    public var isNotesHidden: Bool = false
    /// Temporary hide while another app is fullscreen (see Settings).
    public var suppressedByFullscreen: Bool = false
    public var notesCount: Int = 0
    public var noteListRevealHiddenToken: Int = 0
    /// Note windows in the current multi-selection (e.g. Shift-click on non-text chrome).
    public var selectedNoteIDs: Set<Note.ID> = []

    var areNotesEffectivelyHidden: Bool {
        isNotesHidden || suppressedByFullscreen
    }
}
