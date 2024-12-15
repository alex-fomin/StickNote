import SwiftData
import SwiftUI

@Model
final class Item: Identifiable {
    var id: UUID = UUID()

    var x: CGFloat?
    var y: CGFloat?
    var width: CGFloat?
    var height: CGFloat?

    var text: String = ""
    var color: String

    var fontName: String = NSFont.systemFont(ofSize: 16).fontName
    var fontSize: CGFloat = 16

    init(
        x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil,
        text: String = "", color: String = "Yellow", fontName: String = "", fontSize: CGFloat = 16
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.color = color
        self.fontName = fontName
        self.fontSize = fontSize
    }
}
