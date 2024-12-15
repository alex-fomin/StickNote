import AppKit

class NoteWindow: NSWindow {
    var item: Item?

    override func keyDown(with event: NSEvent) {
        guard let item = item else { return }
        if event.keyCode == 117  // fn+delete
        {
            let alert: NSAlert = NSAlert()
            alert.messageText = #"Are you sure you want to delete "\#(item.text.truncate(15))"?"#
            alert.alertStyle = .warning

            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            let res = alert.runModal()
            if res == .alertFirstButtonReturn {
                AppState.shared.deleteNote(item)
            }
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