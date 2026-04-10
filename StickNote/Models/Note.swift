import AppKit
import SwiftData
import SwiftUI

@Model
final class Note: NoteAppearance, Identifiable {
    @Transient
    var window: NoteWindow?
    
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
    var isHidden: Bool = false
    /// When true, the note is shown as rendered Markdown while not editing; export uses `.md`.
    var isMarkdown: Bool = false
    /// When true, content that looks like Markdown must not auto-enable ``isMarkdown`` (user turned Markdown off).
    var markdownAutoDisabledByUser: Bool = false
    /// Last measured window width/height for markdown display (points), including ``NoteView`` padding. Used to avoid resizing on activation; cleared when text or font changes.
    var markdownFrameWidth: Double?
    var markdownFrameHeight: Double?
    /// When non-nil and in the future, the note is treated as hidden until this instant (then shown again).
    var hiddenUntil: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        x: CGFloat? = nil, y: CGFloat? = nil, isMinimized: Bool = false,
        text: String, color: String, fontName: String, fontSize: CGFloat, fontColor: String,
        isMarkdown: Bool = false
    ) {
        self.x = x
        self.y = y
        self._text = text
        self.color = color
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.isMarkdown = isMarkdown
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
    
    func trim() {
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    func clearMarkdownDisplayFrame() {
        markdownFrameWidth = nil
        markdownFrameHeight = nil
    }

    /// If the trimmed body starts with `#` (Markdown heading), turn Markdown mode on unless the user opted out.
    func applyLikelyMarkdownFlagFromContent() {
        guard !markdownAutoDisabledByUser else { return }
        if Self.textLooksLikeMarkdown(text) {
            isMarkdown = true
        }
    }

    /// Auto-enables Markdown after editing when the note starts with `#` (after trimming whitespace).
    static func textLooksLikeMarkdown(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return t.hasPrefix("#")
    }
}
