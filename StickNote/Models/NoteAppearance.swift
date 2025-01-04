import SwiftUI

protocol NoteAppearance {
    var color: String { get set }

    var fontName: String { get set }
    var fontSize: CGFloat { get set }
    var fontColor: String { get set }
}

extension NoteAppearance {
    func isSameAppearance(_ ap: NoteAppearance) -> Bool {
        self.color == ap.color && self.fontColor == ap.fontColor && self.fontName == ap.fontName
            && self.fontSize == ap.fontSize
    }
}

extension Font {
    init(_ info: NoteAppearance) {
        self.init(NSFont(info))
    }
}

extension NSFont {
    convenience init(_ info: NoteAppearance) {
        self.init(name: info.fontName, size: info.fontSize)!
    }
}
