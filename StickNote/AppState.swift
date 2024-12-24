import AppKit
import Defaults
import KeyboardShortcuts
import SwiftData
import SwiftUI

@MainActor
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

        KeyboardShortcuts.onKeyUp(for: .createNote) { [self] in
            self.openNewNote()
        }
        KeyboardShortcuts.onKeyUp(for: .createNoteFromClipboard) { [self] in
            self.openNewNoteFromClipboard()
        }
        KeyboardShortcuts.onKeyUp(for: .showHideNotes) { [self] in
            self.toggleNotesVisibility()
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
                let size = text.sizeUsingFont(usingFont: note.nsFont)
                note.width = size.width + 16
                note.height = size.height
                self.context.insert(note)
                self.openNote(note, isEditing: false)
            }
        }
    }

    private func openNote(_ note: Note, isEditing: Bool) {
        windowCount += 1

        let contentRect = getContentRectFromNote(note)

        note.x = contentRect.minX
        note.y = contentRect.minY
        note.width = contentRect.width
        note.height = contentRect.height

        let window = NoteWindow(
            contentRect: contentRect,
            styleMask: [
                .titled, .hudWindow, .resizable,
            ],
            backing: .buffered,
            defer: true
        )
        window.note = note
        notesToWindows[note.id] = window

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
            window.makeKey()
        }
        window.styleMask.remove(.titled)

    }

    private func getContentRectFromNote(_ note: Note) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero

        let x = note.x ?? screenFrame.midX - 200 + CGFloat(self.windowCount) * 20
        let y = note.y ?? screenFrame.midY + 150 - CGFloat(self.windowCount) * 20
        let width = note.width ?? 100
        let height = note.height ?? 160

        return NSRect(
            x: x,
            y: y,
            width: width, height: height)
    }

    func openAllNotes() {
        let notes = try? self.context.fetch<Note>(
            FetchDescriptor<Note>(predicate: #Predicate { $0.isInTrashBin == false }))

        if let notes {
            for note in notes {
                if note.text.isEmpty {
                    self.deleteNote(note)
                } else {
                    self.openNote(note, isEditing: false)
                }
            }
        }
    }

    func deleteNote(_ note: Note) {
        if deleteToTrashBin {
            note.isInTrashBin = true
        } else {
            self.context.delete(note)
        }
        try? self.context.save()
        let window = notesToWindows.removeValue(forKey: note.id)
        window?.close()
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
        guard let nsWindow = notesToWindows[note.persistentModelID] else { return }
        if note.showOnAllSpaces {
            nsWindow.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            nsWindow.collectionBehavior.remove(.canJoinAllSpaces)
        }
    }

    var model: AppStateModel = AppStateModel()
}

@Observable class AppStateModel: ObservableObject {
    public var isNotesHidden: Bool = false
}
