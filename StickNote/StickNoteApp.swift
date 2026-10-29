import AppKit
import SwiftData
import SwiftUI
import Defaults
import MenuBarExtraAccess

@main
struct StickNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appStateModel = AppState.shared.model
    @Default(.showNotesCount) var showNotesCount
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.appAppearance) private var appAppearanceRaw
    
    @State var isMenuExtraPresented: Bool = false
    
    var body: some Scene {
#if !targetEnvironment(simulator)
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MainMenu()
                .environment(appStateModel)
        } label: {
            Image(systemName: (appStateModel.areNotesEffectivelyHidden ? "note" : "note.text"))
            if (showNotesCount){
                Text(appStateModel.notesCount > 0 ? "\(appStateModel.notesCount)" : "")
            }
        }
        .menuBarExtraAccess(isPresented: $isMenuExtraPresented, isEnabled: .constant(true)) { statusItem in
            
            if let button = statusItem.button {
                let mouseHandlerView = MouseHandlerView(frame: button.frame)
                
                mouseHandlerView.onMouseDown = {
                    AppState.shared.toggleNotesVisibility()
                }
                mouseHandlerView.onMouseDoubleClick = {
                    AppState.shared.openNewNote()
                }
                
                button.addSubview(mouseHandlerView)
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
                    .preferredColorScheme(
                        (AppAppearancePreference(rawValue: appAppearanceRaw) ?? .system)
                            .preferredColorScheme
                    )
                    .frame(width: 460, height: 520)
            }
        }
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .modelContext(AppState.shared.context)
        .commands {
            CommandGroup(replacing: .appInfo) { }
            CommandGroup(after: .appInfo) {
                Button("New Note") {
                    AppState.shared.openNewNote()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        Window("Note list", id: "note-list") {
            NoteListView()
                .environment(appStateModel)
        }
        .windowLevel(.floating)
        .modelContext(AppState.shared.context)
    }
}

class MouseHandlerView: NSView {
    var onRightMouseDown: (() -> Void)? = nil
    var onMouseDown: (() -> Void)? = nil
    var onMouseDoubleClick: (() -> Void)? = nil
    
    override func rightMouseDown(with event: NSEvent) {
        if let onRightMouseDown {
            onRightMouseDown()
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if (event.clickCount == 2){
            if let onMouseDoubleClick{
                onMouseDoubleClick()
            }
        }else
        if let onMouseDown {
            onMouseDown()
        } else {
            super.mouseDown(with: event)
        }
    }
}
