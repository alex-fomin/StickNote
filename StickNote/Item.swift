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
    
    var color = "Yellow"

    init(
        x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil,
        text: String = ""
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
    }
}
