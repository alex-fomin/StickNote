//
//  WindowPositionTracker.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//


import SwiftUI

class WindowPositionTracker: NSObject, NSWindowDelegate {
    var item: Item
    init(item: Item) {
        self.item = item
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        item.width = window.frame.size.width
        item.height = window.frame.size.height
    }

    // Track when the window is moved
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        item.x = window.frame.origin.x
        item.y = window.frame.origin.y
    }

}