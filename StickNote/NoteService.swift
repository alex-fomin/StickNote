//
//  NoteService.swift
//  StickNote
//
//  Created by Alex Fomin on 11/12/2024.
//

import Cocoa
import RichTextKit
import SwiftData
import SwiftUI

@MainActor
class NoteService {

    static var shared: NoteService?

    var sharedModelContainer: ModelContainer
    var context: ModelContext

    var windowCount: Int = 0

    init() {
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
    }

    func openNewNote() {
        let item = Item()
        self.context.insert(item)

        self.openNote(item, isEditing: true)
    }

    func openNote(_ item: Item, isEditing: Bool) {
        
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
        let contentView = ContentView(item: item, isEditing: isEditing)
            .preferredColorScheme(.light)
            .environment(\.modelContext, self.sharedModelContainer.mainContext)

        window.contentView = NSHostingView(rootView: contentView)
     
        window.level = .floating
        window.isReleasedWhenClosed = false


        window.makeKeyAndOrderFront(nil)
        window.styleMask.remove(.titled)
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
    }
}

class NoteWindow: NSWindow {
    var item: Item?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 117  // fn+delete
        {
            NoteService.shared?.deleteNote(item!)
            self.close()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        self.styleMask.insert(.titled)
        self.makeKey()
        self.styleMask.remove(.titled)
    }
    
    override func becomeKey() {
        super.becomeKey()
        self.hasShadow = true
    }
    
    override func resignKey() {
        super.resignKey()
        self.hasShadow = false
    }
}
