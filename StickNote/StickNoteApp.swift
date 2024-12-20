import SwiftData
import SwiftUI

@main
struct StickNoteApp: App {
    init() {
        AppState.shared.openAllNotes()
    }
    
    @StateObject private var appStateModel = AppState.shared.model
    
    var body: some Scene {
        MenuBarExtra {
            MainMenu(model:AppState.shared.model)
                .environment(appStateModel)
        } label: {
            HStack {
                Image(systemName: (appStateModel.isNotesHidden ? "note" : "note.text"))
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
