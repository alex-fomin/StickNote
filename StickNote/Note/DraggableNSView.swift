//
//  DraggableNSView.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//

import SwiftUI

/// A custom NSView subclass for detecting mouse events to drag the window
class DraggableNSView: NSView {
    var area: DraggableArea?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            DispatchQueue.main.async {
                self.area?.isEditing = true
            }
        } else {
            self.window?.performDrag(with: event)  // Allow window dragging
        }
    }
}
