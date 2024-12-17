import SwiftData
import SwiftUI



@Model
final class Note: NoteAppearance, Identifiable {
    var x: CGFloat?
    var y: CGFloat?
    var width: CGFloat?
    var height: CGFloat?

    var text: String = ""
    var color: String

    var fontName: String
    var fontSize: CGFloat
    var fontColor: String

    init(x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil, text: String, color: String, fontName: String, fontSize: CGFloat, fontColor: String) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.color = color
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
    }
    
    convenience init(layout:Layout, text:String = "") {
        self.init(text:text, color: layout.color, fontName: layout.fontName, fontSize: layout.fontSize, fontColor: layout.fontColor)
    }
    
    func apply(layout:Layout){
        self.color = layout.color
        self.fontColor = layout.fontColor
        self.fontName = layout.fontName
        self.fontSize = layout.fontSize
    }
}

