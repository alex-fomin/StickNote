import AppKit
import SwiftUI

class FontPicker {
    var view: NoteView
    var fontPickerDelegate: FontPickerDelegate?

    init(_ view: NoteView) {
        self.view = view
    }

    func fontSelected() {
        self.view.sharedFont = NSFontPanel.shared.convert(self.view.sharedFont)
    }

    func changeFont() {
        if NSFontPanel.shared.isVisible {
            NSFontPanel.shared.orderOut(nil)

            if NSFontManager.shared.target === self.fontPickerDelegate {
                return
            }
        }

        self.fontPickerDelegate = FontPickerDelegate(self)
        NSFontManager.shared.target = self.fontPickerDelegate
        NSFontPanel.shared.setPanelFont(self.view.sharedFont, isMultiple: false)
        NSFontPanel.shared.orderBack(nil)
    }
}

class FontPickerDelegate {
    var parent: FontPicker

    init(_ parent: FontPicker) {
        self.parent = parent
    }

    @objc
    func changeFont(_ id: Any) {
        parent.fontSelected()
    }

}
