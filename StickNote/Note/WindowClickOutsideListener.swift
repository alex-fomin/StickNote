//
//  WindowClickOutsideListener.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//

import SwiftUI

/// A helper NSViewRepresentable to listen for global clicks outside the SwiftUI window
struct WindowClickOutsideListener: NSViewRepresentable {
    @Binding var isEditing: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            DispatchQueue.main.async {
                self.isEditing = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

}
