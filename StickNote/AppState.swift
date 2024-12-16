import AppKit
import KeyboardShortcuts
import SwiftData
import SwiftUI

@MainActor
final class AppState {

    static let shared: AppState = AppState()

    var sharedModelContainer: ModelContainer
    var context: ModelContext

    var windowCount: Int = 0

    var notesToWindows: [UUID: NSWindow] = [:]

    private init() {
        self.sharedModelContainer = {
            let schema = Schema([
                Note.self,
                Layout.self,
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

        let layouts = try? self.context.fetch<Category>(FetchDescriptor<Layout>())
        if layouts == nil || layouts?.isEmpty == true {
            let defaultLayouts = Layout.defaultLayouts()

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
    }

    func getDefaultLayout() -> Layout {
        return
            (try? self.context.fetch<Category>(
                FetchDescriptor<Layout>(predicate: #Predicate { $0.isDefault == true })))?.first
            ?? Layout.defaultLayout
    }

    func openNewNote() {
        let note = Note(layout: getDefaultLayout())
        self.context.insert(note)

        self.openNote(note, isEditing: true)
    }

    func openNewNoteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            if !text.isEmpty {
                let note = Note(layout: getDefaultLayout(), text: text)
                self.context.insert(note)
                self.openNote(note, isEditing: false)
            }
        }
    }

    private func openNote(_ note: Note, isEditing: Bool) {

        windowCount += 1

        let contentRect = getContentRectFromNote(note)

        let window = NoteWindow(
            contentRect: contentRect,
            styleMask: [
                .titled, .resizable, .borderless, .fullSizeContentView,
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

        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces]
        window.makeKeyAndOrderFront(nil)
        window.styleMask.remove(.titled)
        notesToWindows[note.id] = window
    }

    private func getContentRectFromNote(_ note: Note) -> NSRect {

        if let x = note.x,
            let y = note.y,
            let width = note.width,
            let height = note.height
        {
            return NSRect(x: x, y: y, width: width, height: height)
        } else {
            let screenFrame = NSScreen.main?.frame ?? NSRect.zero

            return NSRect(
                x: screenFrame.midX - 200 + CGFloat(self.windowCount) * 20,
                y: screenFrame.midY + 150 - CGFloat(self.windowCount) * 20,
                width: 100, height: 300)
        }
    }

    func openAllNotes() {
        let notes = try? self.context.fetch<Note>(FetchDescriptor<Note>())

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
        self.context.delete(note)
        try? self.context.save()
        let window = notesToWindows.removeValue(forKey: note.id)
        window?.close()
    }

    func copyToClipboard(_ note: Note) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }
}
