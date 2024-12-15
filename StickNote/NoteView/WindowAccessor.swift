//
//  WindowAccessor.swift
//  StickNote
//
//  Created by Alex Fomin on 15/12/2024.
//


import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // Retrieve the `NSWindow` after the view is added to the hierarchy
            callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}