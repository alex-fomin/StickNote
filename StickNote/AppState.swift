import Defaults
import SwiftData
import SwiftUI

final class AppState {

    static let shared: AppState = AppState()
    @Default(.deleteToTrashBin) var deleteToTrashBin

    var sharedModelContainer: ModelContainer
    var context: ModelContext

    var windowCount: Int = 0

    var notesToWindows: [PersistentIdentifier: NSWindow] = [:]

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
    }

    func openNewNoteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            if !text.isEmpty {
                let note = Note(layout: getDefaultLayout(), text: text)
                note.showOnAllSpaces = Defaults[.showOnAllSpaces]
                self.context.insert(note)
                self.openNote(note, isEditing: false)
            }
        }
    }

    func openNote(_ note: Note, isEditing: Bool) {
        windowCount += 1

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
        notesToWindows[note.id] = window
    }

    private func getContentRectFromNote(_ note: Note) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero

        let x = note.x ?? (screenFrame.midX - 500 + CGFloat(self.windowCount) * 20)
        let y = note.y ?? (screenFrame.midY + 450 - CGFloat(self.windowCount) * 20)

        return NSRect(
            x: x,
            y: y,
            width: 10, height: 10)
    }

    func openAllNotes() {
        let notes = try? self.context.fetch<Note>(
            FetchDescriptor<Note>(predicate: #Predicate { $0.isInTrashBin == false }))

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

        let window = notesToWindows.removeValue(forKey: note.id)
        window?.close()

        if forceDelete || !deleteToTrashBin {
            self.context.delete(note)
        } else {
            note.isInTrashBin = true
            note.updatedAt = Date.now
        }
        try? self.context.save()

    }

    func copyToClipboard(_ note: Note) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }

    func toggleNotesVisibility() {
        for (_, window) in notesToWindows {
            if model.isNotesHidden {
                window.orderFront(nil)
            } else {
                window.orderOut(nil)
            }
        }
        model.isNotesHidden = !model.isNotesHidden
    }

    func applyShowOnAllSpaces(note: Note) {
        guard let nsWindow = notesToWindows[note.id] else { return }
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
}
