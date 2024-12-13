import AppKit

class NoteWindow: NSWindow {
    var item: Item?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 117  // fn+delete
        {
            AppState.shared.deleteNote(item!)
            self.close()
        }
        else if event.keyCode == 8 &&
                    event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command// Cmd+c
        {
            if let text = item?.text {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
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
