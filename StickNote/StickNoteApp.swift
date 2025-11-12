import AppKit
import SwiftData
import SwiftUI
import Defaults

@main
struct StickNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appStateModel = AppState.shared.model
    @Default(.showNotesCount) var showNotesCount
    
    var body: some Scene {
        #if !targetEnvironment(simulator)
            MenuBarExtra {
                MainMenu(model: AppState.shared.model)
                    .environment(appStateModel)
            } label: {
                Image(systemName: (appStateModel.isNotesHidden ? "note" : "note.text"))
                if (showNotesCount){
                    Text(appStateModel.notesCount > 0 ? "\(appStateModel.notesCount)" : "")
                }
            }
        #endif

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

        Window("Note list", id: "note-list") {
            NoteListView()
        }
        .modelContext(AppState.shared.context)

        Settings {
            SettingsView()
                .fixedSize()
        }
        .windowResizability(.contentSize)
        .modelContext(AppState.shared.context)
    }
}
