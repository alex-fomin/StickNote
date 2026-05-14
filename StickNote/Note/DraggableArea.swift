//
//  DraggableArea.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//

import AppKit
import SwiftUI

/// A helper view that enables dragging the entire window
struct DraggableArea: NSViewRepresentable {
    @Binding var isEditing: Bool
    var allowsEditOnDoubleClick: Bool = true
    /// When set, invoked on double-click before edit/drag logic (e.g. restore a minimized image note).
    var onDoubleClick: (() -> Void)? = nil
    /// Shown via ``NoteHoverTooltipWindow`` (non-key windows do not show ``NSView/toolTip`` reliably).
    var toolTip: String? = nil

    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        view.area = self
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor  // Transparent layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? DraggableNSView else { return }
        view.area = self
        view.toolTip = ""
    }
}
