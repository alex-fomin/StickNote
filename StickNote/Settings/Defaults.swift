import Defaults

extension Defaults.Keys {
    /// Set after the first-launch Settings presentation so a fresh install shows Settings once.
    static let hasCompletedFirstLaunch = Key<Bool>("has-completed-first-launch", default: false)
    static let confirmOnDelete = Key<Bool>("confirm-on-delete", default: true)
    static let showOnAllSpaces = Key<Bool>("show-on-all-spaces", default: true)
    static let deleteToTrashBin = Key<Bool>("delete-to-trash-bin", default: true)
    static let maximizeOnHover = Key<Bool>("maximize-on-hover", default: true)
    static let maximizeOnEdit = Key<Bool>("maximize-on-edit", default: false)
    static let trimAfterPaste = Key<Bool>("trim-after-paste", default: false)
    /// Word-wrap long lines when pasting a new note from the clipboard (after trim, if enabled).
    static let wrapLongLinesAfterPaste = Key<Bool>("wrap-long-lines-after-paste", default: false)
    static let showNotesCount = Key<Bool>("show-notes-count", default: true)
    static let showMenuBarIcon = Key<Bool>("show-menu-bar-icon", default: true)
    /// Hides floating notes while another app is in native fullscreen on the active space.
    static let hideNotesWhenFullscreenApp = Key<Bool>("hide-notes-when-fullscreen-app", default: false)

    /// `system` | `light` | `dark` — drives `NSApp.appearance` via ``AppAppearance``.
    static let appAppearance = Key<String>("app-appearance", default: "system")
}
