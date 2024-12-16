//
//  WindowPositionTracker.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//


import SwiftUI

class WindowPositionTracker: NSObject, NSWindowDelegate {
    var note: Note
    init(note: Note) {
        self.note = note
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        note.width = window.frame.size.width
        note.height = window.frame.size.height
    }

    // Track when the window is moved
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        note.x = window.frame.origin.x
        note.y = window.frame.origin.y
    }

}
