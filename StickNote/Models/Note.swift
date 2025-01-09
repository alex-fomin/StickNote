import AppKit
import SwiftData
import SwiftUI

@Model
final class Note: NoteAppearance, Identifiable {
    var x: CGFloat?
    var y: CGFloat?
    var isMinimized: Bool = false

    var text: String = ""
    var color: String

    var fontName: String
    var fontSize: CGFloat
    var fontColor: String

    var showOnAllSpaces: Bool = true

    var isInTrashBin: Bool = false

    init(
        x: CGFloat? = nil, y: CGFloat? = nil, isMinimized: Bool = false,
        text: String, color: String, fontName: String, fontSize: CGFloat, fontColor: String
    ) {
        self.x = x
        self.y = y
        self.text = text
        self.color = color
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
    }

    convenience init(layout: NoteLayout, text: String = "") {
        self.init(
            text: text, color: layout.color, fontName: layout.fontName, fontSize: layout.fontSize,
            fontColor: layout.fontColor)
    }

    func apply(layout: NoteLayout) {
        self.color = layout.color
        self.fontColor = layout.fontColor
        self.fontName = layout.fontName
        self.fontSize = layout.fontSize
    }
}
