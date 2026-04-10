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
            if let onDoubleClick = area?.onDoubleClick {
                DispatchQueue.main.async {
                    onDoubleClick()
                }
                return
            }
            if self.area?.allowsEditOnDoubleClick ?? true {
                DispatchQueue.main.async {
                    self.area?.isEditing = true
                }
                return
            }
        }
        self.window?.performDrag(with: event)  // Allow window dragging
    }
}
