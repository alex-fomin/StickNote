import AppKit
import SwiftData
import SwiftUI

@Model
final class Note: NoteAppearance, Identifiable {
    var x: CGFloat?
    var y: CGFloat?
    var isMinimized: Bool = false

    private var _text: String
    var text: String {
        get { _text }
        set(newText) {
            _text = newText
            updatedAt = Date.now
        }

    }

    var color: String

    var fontName: String
    var fontSize: CGFloat
    var fontColor: String

    var showOnAllSpaces: Bool = true

    var isInTrashBin: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        x: CGFloat? = nil, y: CGFloat? = nil, isMinimized: Bool = false,
        text: String, color: String, fontName: String, fontSize: CGFloat, fontColor: String
    ) {
        self.x = x
        self.y = y
        self._text = text
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
