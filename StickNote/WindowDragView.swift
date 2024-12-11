import SwiftUI
import Cocoa

class WindowDragView<Content>: NSHostingView<Content>  where Content : View {
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
