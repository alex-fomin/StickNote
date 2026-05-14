//
//  DraggableNSView.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//

import AppKit
import SwiftUI

/// A custom NSView subclass for detecting mouse events to drag the window
class DraggableNSView: NSView {
    var area: DraggableArea?

    private var hoverTrackingArea: NSTrackingArea?
    private var hoverTipWorkItem: DispatchWorkItem?

    private static let hoverTipDelay: TimeInterval = 0.65

    /// While Command is held, let hits fall through so SwiftUI/Textual can handle Cmd+click on links.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if NSEvent.modifierFlags.contains(.command) {
            return nil
        }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        // ``activeAlways``: receive moves while this window is not key (system ``toolTip`` does not show in that case).
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        let ta = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(ta)
        hoverTrackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        scheduleHoverTipIfNeeded()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        scheduleHoverTipIfNeeded()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        cancelHoverTip()
        NoteHoverTooltipWindow.hide()
    }

    override func mouseDown(with event: NSEvent) {
        NoteHoverTooltipWindow.hide()
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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Shift-click is for multi-select (see ``NoteWindow``); do not start a window drag.
        if flags.contains(.shift) {
            return
        }
        self.window?.performDrag(with: event)  // Allow window dragging
    }

    override func removeFromSuperview() {
        cancelHoverTip()
        NoteHoverTooltipWindow.hide()
        super.removeFromSuperview()
    }

    private func scheduleHoverTipIfNeeded() {
        guard let tip = area?.toolTip, !tip.isEmpty else { return }
        cancelHoverTip()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.window != nil else { return }
            guard let tip = self.area?.toolTip, !tip.isEmpty else { return }
            guard let win = self.window else { return }
            NoteHoverTooltipWindow.show(text: tip, anchoring: win)
        }
        hoverTipWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverTipDelay, execute: work)
    }

    private func cancelHoverTip() {
        hoverTipWorkItem?.cancel()
        hoverTipWorkItem = nil
    }
}
