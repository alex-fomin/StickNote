import SwiftData
import SwiftUI

@main
struct StickNoteApp: App {
    init() {
        AppState.shared.openAllNotes()
    }
    var body: some Scene {
        MenuBarExtra {
            MainMenu()
        } label: {
            HStack {
                Image(systemName: "note.text")
            }
        }

        WindowGroup(id: "note-layout", for: Note.ID.self) { $id in

            if let id = id,
                let note =
                    (try? AppState.shared.context.fetch<Category>(
                        FetchDescriptor<Note>(predicate: #Predicate { $0.persistentModelID == id })))?
                    .first
            {
                NoteLayoutView(note: note)
                    .frame(
                        minWidth: 400, maxWidth: 400,
                        minHeight: 200, maxHeight: 200)
            }

        }
        .windowResizability(.contentSize)
        .modelContext(AppState.shared.context)

        Settings {
            SettingsView()
        }
        .modelContext(AppState.shared.context)
    }
}
