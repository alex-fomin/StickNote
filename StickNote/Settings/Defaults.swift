import Defaults

extension Defaults.Keys {
    static let confirmOnDelete = Key<Bool>("confirm-on-delete", default: true)
    static let showOnAllSpaces = Key<Bool>("show-on-all-spaces", default: true)
    static let deleteToTrashBin = Key<Bool>("delete-to-trash-bin", default: true)
    static let onHover = Key<OnHover>("on-hover", default: .maximize)
}

enum OnHover: String, Defaults.Serializable {
    case nothing
    case maximize
    case showTooltip
}
