import SwiftUI
import SwiftData
import RichTextKit
import Cocoa

struct MainMenu : View{
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        
        Button("Add new note"){
            NoteService.shared?.openNewNote()
        }
        .keyboardShortcut("N")
        
        Divider()
        Button("Settings"){openSettings()}
        
        Button("Exit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}


