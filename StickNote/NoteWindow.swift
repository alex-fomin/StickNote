import AppKit

class NoteWindow: NSWindow {
    var item: Item?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 117  // fn+delete
        {
            AppState.shared.deleteNote(item!)
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
