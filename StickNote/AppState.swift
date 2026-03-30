import Defaults
import Foundation
import SwiftData
import SwiftUI

final class AppState {

    static let shared: AppState = AppState()
    @Default(.deleteToTrashBin) var deleteToTrashBin
    @Default(.trimAfterPaste) var trimAfterPaste

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
        let note = Note(layout: getDefaultLayout())
        note.showOnAllSpaces = Defaults[.showOnAllSpaces]
        self.context.insert(note)
       
        
        self.openNote(note, isEditing: true)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openNewNoteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            if !text.isEmpty {
                let note = Note(layout: getDefaultLayout(), text: text)
                if (trimAfterPaste){
                    note.trim()
                }
                note.showOnAllSpaces = Defaults[.showOnAllSpaces]
                self.context.insert(note)
                
                self.openNote(note, isEditing: false)
            }
        }
    }

    func openNote(_ note: Note, isEditing: Bool) {
        if let existing = note.window {
            existing.orderFront(nil)
            if isEditing {
                NSApplication.shared.activate(ignoringOtherApps: true)
                existing.makeKey()
            }
            return
        }

        let contentRect = getContentRectFromNote(note)

        note.x = contentRect.minX
        note.y = contentRect.minY

        let window = NoteWindow(
            contentRect: contentRect,
            styleMask: [
                .titled
            ],
            backing: .buffered,
            defer: true
        )
        window.note = note
        note.window = window

        let contentView = NoteView(note: note, isEditing: isEditing)
            .preferredColorScheme(.light)
            .environment(\.modelContext, self.sharedModelContainer.mainContext)

        window.contentView = NSHostingView(rootView: contentView)

        window.level = .floating
        window.hasShadow = isEditing
        window.isReleasedWhenClosed = false

        applyShowOnAllSpaces(note: note)

        window.orderFront(nil)
        if isEditing {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKey()
        }

        window.styleMask.remove(.titled)

        try? context.save()
        self.updateNotesCount()
        self.windows.append(window);
    }

    private func getContentRectFromNote(_ note: Note) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero

        let x = note.x ?? (screenFrame.midX - 500 + CGFloat(self.windows.count) * 20)
        let y = note.y ?? (screenFrame.midY + 450 - CGFloat(self.windows.count) * 20)

        return NSRect(
            x: x,
            y: y,
            width: 10, height: 10)
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
            if !note.text.isEmpty {
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
                if note.text.isEmpty {
                    self.deleteNote(note, forceDelete: true)
                } else {
                    self.openNote(note, isEditing: false)
                }
            }
        }
    }

    func deleteNote(_ note: Note, forceDelete: Bool = false) {
        if let window = note.window {
            note.window = nil
            window.close()
            self.windows.removeAll { $0 === window }
        }

        if forceDelete || !deleteToTrashBin {
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
    
    func copyToClipboard(_ note: Note) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }

    func toggleNotesVisibility() {
       
        for window in self.windows {
            if model.isNotesHidden {
                window.orderFront(nil)
            } else {
                window.orderOut(nil)
            }
        }
        model.isNotesHidden = !model.isNotesHidden
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

    var model: AppStateModel = AppStateModel()
}

@Observable class AppStateModel: ObservableObject {
    public var isNotesHidden: Bool = false
    public var notesCount: Int = 0
    public var noteListRevealHiddenToken: Int = 0
}
