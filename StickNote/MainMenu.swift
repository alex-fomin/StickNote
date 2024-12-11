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
                styleMask: [.titled],
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
//
//class CustomWindow: NSWindow {
//    private let resizeAreaSize: CGFloat = 5.0
//
//    override func performDrag(with event: NSEvent) {
//        print("drag")
//        let mouseLocation = event.locationInWindow
//        let windowFrame = self.frame
//
//        let resizeArea = NSRect(
//            x: windowFrame.width - resizeAreaSize,
//            y: windowFrame.height - resizeAreaSize,
//            width: resizeAreaSize,
//            height: resizeAreaSize
//        )
//        print("drag \(windowFrame) \(resizeArea)  \(mouseLocation)")
//
//        if resizeArea.contains(mouseLocation) {
//            print("resize")
//            // Perform custom resize logic
//        } else {
//            super.performDrag(with: event)
//        }
//    }
//}
