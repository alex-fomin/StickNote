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
    
    var itemsToWindows:[UUID:NSWindow] = [:]
    
    private init() {
        self.sharedModelContainer = {
            let schema = Schema([
                Item.self
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
        
        KeyboardShortcuts.onKeyUp(for: .createNote) { [self] in
            self.openNewNote()
        }
        KeyboardShortcuts.onKeyUp(for: .createNoteFromClipboard) { [self] in
            self.openNewNoteFromClipboard()
        }
    }
    
    func openNewNote() {
        let item = Item()
        self.context.insert(item)
        
        self.openNote(item, isEditing: true)
    }
    
    func openNewNoteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            if !text.isEmpty {
                let item = Item(text: text)
                self.context.insert(item)
                self.openNote(item, isEditing: false)
            }
        }
    }
    
    private func openNote(_ item: Item, isEditing: Bool) {
        
        windowCount += 1
        
        let contentRect = getContentRectFromItem(item)
        
        let window = NoteWindow(
            contentRect: contentRect,
            styleMask: [
                .titled, .resizable, .borderless, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: true
        )
        window.item = item
        
        let contentView = NoteView(item: item, isEditing: isEditing)
            .preferredColorScheme(.light)
            .environment(\.modelContext, self.sharedModelContainer.mainContext)
        
        window.contentView = NSHostingView(rootView: contentView)
        
        window.level = .floating
        
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces]
        window.makeKeyAndOrderFront(nil)
        window.styleMask.remove(.titled)
        itemsToWindows[item.id] = window
    }
    
    private func getContentRectFromItem(_ item: Item) -> NSRect {
        
        if let x = item.x,
           let y = item.y,
           let width = item.width,
           let height = item.height
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
        let fetchAll = FetchDescriptor<Item>()
        
        let items = try? self.context.fetch<Item>(fetchAll)
        
        if let items {
            for item in items {
                if item.text.isEmpty {
                    self.deleteNote(item)
                } else {
                    self.openNote(item, isEditing: false)
                }
            }
        }
    }
    
    func deleteNote(_ item: Item) {
        self.context.delete(item)
        try? self.context.save()
        let window = itemsToWindows.removeValue(forKey: item.id)
        window?.close()
    }
    
    func copyToClipboard(_ item: Item){
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}


