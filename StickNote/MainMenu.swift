import SwiftUI
import SwiftData
import RichTextKit
import Cocoa

struct MainMenu : View{
    @Environment(\.openSettings) private var openSettings
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        
        Button("Add new note"){
            let contentView = ContentView(            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.resizable,.fullSizeContentView,.titled],
                backing: .buffered,
                defer: true
            )
            window.center()
            window.titleVisibility = .hidden // Hides the title
            window.titlebarAppearsTransparent = true // Makes the title bar transparent
            
            window.level = .floating
            
            window.contentView = WindowDragView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
            window.styleMask.remove(.titled) // Removes the title bar
            
        }
        .keyboardShortcut("N")
        
        Divider()
        Button("Settings"){openSettings()}
        
        Button("Exit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}
