import Defaults

extension Defaults.Keys {
    static let confirmOnDelete = Key<Bool>("confirm-on-delete", default: true)
    static let showOnAllSpaces = Key<Bool>("show-on-all-spaces", default: true)
    static let deleteToTrashBin = Key<Bool>("delete-to-trash-bin", default: true)
    static let maximizeOnHover = Key<Bool>("maximize-on-hover", default: true)
    static let maximizeOnEdit = Key<Bool>("maximize-on-edit", default: false)
}
