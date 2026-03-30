import Foundation
import KeyboardShortcuts

extension Notification.Name {
    static let stickNoteRevealHiddenNotesInList = Notification.Name("stickNoteRevealHiddenNotesInList")
}

extension KeyboardShortcuts.Name {
    static let createNote = Self("createNote")
    static let createNoteFromClipboard = Self("createNoteFromClipboard")
    static let showHideNotes = Self("showHideNotes")
}
