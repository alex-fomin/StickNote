import SwiftData
import SwiftUI

@Model
final class NoteLayout: Identifiable, NoteAppearance {
    var id: UUID = UUID()

    var name: String
    var color: String
    var fontName: String
    var fontSize: CGFloat
    var fontColor: String
    var isDefault: Bool = false

    init(
        name: String, color: String, fontName: String, fontSize: CGFloat, fontColor: String,
        isDefault: Bool = false
    ) {
        self.name = name
        self.color = color
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.isDefault = isDefault
    }

    static func defaultLayouts() -> [NoteLayout] {
        let defaultLayout = defaultLayout
        return [
            defaultLayout,
            .init(
                name: "Green", color: "#CDFC93", fontName: defaultLayout.fontName,
                fontSize: defaultLayout.fontSize, fontColor: defaultLayout.fontColor),
            .init(
                name: "Blue", color: "#71D7FF", fontName: defaultLayout.fontName,
                fontSize: defaultLayout.fontSize, fontColor: defaultLayout.fontColor),
            .init(
                name: "Pink", color: "#FF7ECD", fontName: defaultLayout.fontName,
                fontSize: defaultLayout.fontSize, fontColor: defaultLayout.fontColor),
            .init(
                name: "Purple", color: "#CE81FF", fontName: defaultLayout.fontName,
                fontSize: defaultLayout.fontSize, fontColor: "#FFFFFF"),
            .init(
                name: "Alert", color: "#FF0000", fontName: defaultLayout.fontName, fontSize: 40,
                fontColor: "#FFFFFF"),
        ]
    }

    static var defaultLayout: NoteLayout {
        let systemFont = NSFont.systemFont(ofSize: 16)
        return .init(
            name: "Yellow", color: "#FFF68B", fontName: "SFCompact-Regular",
            fontSize: systemFont.pointSize, fontColor: "#000000", isDefault: true)
    }
}
