import AppKit
import Defaults

class NoteWindow: NSWindow {
    var note: Note?
    @Default(.confirmOnDelete) var confirmOnDelete

    /// True if `view` or any ancestor is an ``NSTextView`` (so Command+click stays for text selection).
    private static func viewHierarchyContainsTextView(_ view: NSView?) -> Bool {
        var v: NSView? = view
        while let cur = v {
            if cur is NSTextView { return true }
            v = cur.superview
        }
        return false
    }

    override func sendEvent(_ event: NSEvent) {
        if let note = note,
            event.window === self,
            event.type == .leftMouseDown,
            event.buttonNumber == 0,
            let cv = contentView
        {
            let locationInContent = cv.convert(event.locationInWindow, from: nil)
            let hitView = cv.hitTest(locationInContent)
            let inTextEditor = Self.viewHierarchyContainsTextView(hitView)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if flags.contains(.command) {
                if !inTextEditor {
                    AppState.shared.toggleSelection(for: note)
                }
            } else {
                AppState.shared.replaceSelection(with: note)
            }
        }
        super.sendEvent(event)
    }

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
            note.fontSize += 1
        }
        else if (event.keyCode == 27 && isCmd(event)) //Cmd -
        {
            if note.fontSize > 5 {
                note.fontSize -= 1
            }
        }
        else if isCmd(event),
            event.charactersIgnoringModifiers == "0" || event.keyCode == 82
        {  // Cmd+0 (main keyboard or keypad)
            AppState.shared.postResetZoom(for: note)
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
