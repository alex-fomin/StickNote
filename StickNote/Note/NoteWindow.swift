import AppKit
import Defaults

class NoteWindow: NSWindow {
    var note: Note?
    @Default(.confirmOnDelete) var confirmOnDelete

    override func keyDown(with event: NSEvent) {
        guard let note = note else { return }
        if event.keyCode == 117  // fn+delete
        {
            if confirmOnDelete {
                let alert: NSAlert = NSAlert()
                alert.messageText =
                    #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#
                alert.alertStyle = .warning

                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")
                let res = alert.runModal()
                if res == .alertFirstButtonReturn {
                    self.close()
                    AppState.shared.deleteNote(note)
                }
            }
            else {
                self.close()
                AppState.shared.deleteNote(note)
            }
        } else if event.keyCode == 8
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command  // Cmd+c
        {
            AppState.shared.copyToClipboard(note)
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
