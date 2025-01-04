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
    
    var nsFont: NSFont {
        if let nsFont = NSFont(name: fontName, size: NSFont.systemFontSize) {
            print ("Bote", fontName)
            return nsFont.withSize(fontSize)
        } else {
            print("system", NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName)
            return NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
    }
}

extension Font {
    init(_ info: NoteAppearance) {
        self.init(info.nsFont)
    }
}
