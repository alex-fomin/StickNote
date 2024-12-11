import SwiftUI
import SwiftData
import RichTextKit
import Cocoa

struct MainMenu : View{
    @Environment(\.openSettings) private var openSettings
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        
        Button("Add new note"){
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                styleMask: [.titled, .resizable, .borderless],
                backing: .buffered,
                defer: true
            )
            window.center()
            
            window.level = .floating
            window.isReleasedWhenClosed = false
            
            let contentView = ContentView()
            window.contentView = NSHostingView(rootView: contentView)
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
