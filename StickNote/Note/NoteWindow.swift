import AppKit
import Defaults

class NoteWindow: NSWindow {
    var note: Note?
    @Default(.confirmOnDelete) var confirmOnDelete

    override func keyDown(with event: NSEvent) {
        guard let note = note else { return }
        if event.keyCode == 117 || (event.keyCode == 51 && isCmd(event)) // fn+delete || cmd+delete
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
            } else {
                self.close()
                AppState.shared.deleteNote(note)
            }
        } else if event.keyCode == 8 && isCmd(event)  // Cmd+c
        {
            AppState.shared.copyToClipboard(note)
        }
        else if (event.keyCode == 24 && isCmd(event)) //Cmd +
        {
            if !note.isImageNote {
                note.fontSize += 1
            }
        }
        else if (event.keyCode == 27 && isCmd(event)) //Cmd -
        {
            if !note.isImageNote, note.fontSize > 5 {
                note.fontSize -= 1
            }
        }
        
        func isCmd(_ event: NSEvent)->Bool{
            return event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let saved = self.frame
        self.styleMask.insert(.titled)
        self.makeKey()
        self.styleMask.remove(.titled)
        self.setFrame(saved, display: true)
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
