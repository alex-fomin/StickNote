import AppKit
import Foundation
import KeyboardShortcuts

extension NSEvent {
    /// Plain Command+N (no shift/option/control), keyDown — matches the standard “New” shortcut.
    var stickNote_isCommandPlainN: Bool {
        type == .keyDown
            && modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            && charactersIgnoringModifiers?.lowercased() == "n"
    }
}

extension Notification.Name {
    static let stickNoteRevealHiddenNotesInList = Notification.Name("stickNoteRevealHiddenNotesInList")
}

extension KeyboardShortcuts.Name {
    static let createNote = Self("createNote")
    static let createNoteFromClipboard = Self("createNoteFromClipboard")
    static let showHideNotes = Self("showHideNotes")
}
