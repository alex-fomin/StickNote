import SwiftUI

protocol NoteAppearance {
    var color: String{get set}

    var fontName: String{get set}
    var fontSize: CGFloat{get set}
    var fontColor: String{get set}
}


extension Font{
    init(_ info:NoteAppearance){
        self.init(NSFont(info))
    }
}

extension NSFont {
    convenience init(_ info:NoteAppearance){
        self.init(name: info.fontName, size: info.fontSize)!
    }
}
