import AppKit
import Foundation
import Textual

/// Measures rendered markdown without ``NSHostingView``. Uses the same parser as ``NoteTextView`` and
/// ``NSAttributedString.boundingRect`` (``NSLayoutManager``/``usedRect`` proved unreliable for multi-line height).
@MainActor
enum MarkdownDisplaySize {
    static func fittingSize(for note: Note) -> CGSize {
        let parsed: AttributedString
        do {
            parsed = try StickNoteMarkdownParser().attributedString(for: note.text)
        } catch {
            return note.text.sizeUsingFont(usingFont: note.nsFont)
        }

        let baseFont = note.nsFont
        let semiboldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        let mutable = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        guard mutable.length > 0 else {
            return note.text.sizeUsingFont(usingFont: note.nsFont)
        }

        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: baseFont, range: fullRange)

        for run in parsed.runs {
            let nsRange = NSRange(run.range, in: parsed)
            let isHeading = run.presentationIntent.map { intent in
                intent.components.contains { component in
                    if case .header = component.kind { return true }
                    return false
                }
            } ?? false
            if isHeading {
                mutable.addAttribute(.font, value: semiboldFont, range: nsRange)
            }
        }

        let plain = mutable.string as String
        let pt = baseFont.pointSize
        let extraLineSpacing = 0.1 * pt
        let blockTop = 0.75 * pt
        let blockBottom = 0.35 * pt

        let nsPlain = plain as NSString
        nsPlain.enumerateSubstrings(
            in: NSRange(location: 0, length: nsPlain.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, paragraphRange, _, _ in
            guard let swiftRange = Range(paragraphRange, in: plain) else { return }
            let charStart = plain.distance(from: plain.startIndex, to: swiftRange.lowerBound)
            let charEnd = plain.distance(from: plain.startIndex, to: swiftRange.upperBound)
            let isHeading: Bool = {
                guard charStart < charEnd else { return false }
                let a = parsed.index(parsed.startIndex, offsetByCharacters: charStart)
                let b = parsed.index(parsed.startIndex, offsetByCharacters: charEnd)
                return parsed[a..<b].runs.contains { run in
                    run.presentationIntent.map { intent in
                        intent.components.contains { component in
                            if case .header = component.kind { return true }
                            return false
                        }
                    } ?? false
                }
            }()

            let style = NSMutableParagraphStyle()
            if isHeading {
                style.lineSpacing = extraLineSpacing
                style.paragraphSpacingBefore = blockTop
                style.paragraphSpacing = blockBottom
            }
            mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
        }

        let maxWidth: CGFloat = 10_000
        let rect = mutable.boundingRect(
            with: NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let measuredW = ceil(rect.width)
        let measuredH = ceil(rect.height)
        let fallback = note.text.sizeUsingFont(usingFont: note.nsFont)
        // Width: use the rendered attributed string only. Do not take `max` with `fallback.width`:
        // fallback measures raw `note.text` (still contains `#`), so it is wider than on-screen markdown.
        if measuredW > 0, measuredH > 0 {
            return CGSize(width: max(20, measuredW), height: max(measuredH, fallback.height))
        }
        return fallback
    }
}
