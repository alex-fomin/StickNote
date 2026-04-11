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
    static let showNotesCount = Key<Bool>("show-notes-count", default: true)
    static let showMenuBarIcon = Key<Bool>("show-menu-bar-icon", default: true)
}
