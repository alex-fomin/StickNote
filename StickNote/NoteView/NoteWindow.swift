import AppKit

class NoteWindow: NSWindow {
    var item: Item?

    override func keyDown(with event: NSEvent) {
        guard let item = item else { return }
        if event.keyCode == 117  // fn+delete
        {
            AppState.shared.deleteNote(item)
        } else if event.keyCode == 8
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command  // Cmd+c
        {
            AppState.shared.copyToClipboard(item)
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        self.styleMask.insert(.titled)
        self.makeKey()
        self.styleMask.remove(.titled)
    }

    override func becomeKey() {
        self.hasShadow = true
        super.becomeKey()
    }

    override func resignKey() {
        self.hasShadow = false
        super.resignKey()
    }
}
