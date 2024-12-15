import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let createNote = Self("createNote")
    static let createNoteFromClipboard = Self("createNoteFromClipboard")
}

enum NoteColors: String, CaseIterable {
    case Blue = "Blue"
    case Pink = "Pink"
    case Purple = "Purple"
    case Green = "Green"
    case Yellow = "Yellow"
    
//    let values: [String] = allCases.map { $0.rawValue }
}
