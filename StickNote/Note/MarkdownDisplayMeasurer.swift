import AppKit
import SwiftUI
import Textual

/// Renders markdown in an invisible, off-screen window and reads the laid-out size so it matches
/// on-screen ``StructuredText`` (no duplicated heuristics).
@MainActor
final class MarkdownDisplayMeasurer {
    static let shared = MarkdownDisplayMeasurer()

    private var window: NSWindow?
    private var hosting: NSHostingView<MarkdownMeasureRoot>?

    private init() {}

    /// Measures the note’s rendered markdown size. Calls `completion` on the main queue once (or with a fallback if layout fails).
    /// - Parameter contentMaxWidth: Upper bound for line wrapping during layout; pass `nil` to use a large default so width/height follow rendered markdown (plain-text width is a poor cap for headings, code, etc.).
    func measure(note: Note, contentMaxWidth: CGFloat?, completion: @escaping @MainActor (CGSize) -> Void) {
        var finished = false
        let finishOnce: @MainActor (CGSize) -> Void = { size in
            guard !finished else { return }
            finished = true
            let w = max(20, size.width) + 1
            let h = max(1, size.height)
            completion(CGSize(width: w, height: h))
        }

        let maxW = contentMaxWidth.map { max(1, $0) } ?? 10_000

        // Updated by MarkdownMeasureRoot as SwiftUI lays out; default StructuredText can take several
        // passes (e.g. headings), so we must not complete measurement on the first value.
        var reportedSize: CGSize = .zero

        let root = MarkdownMeasureRoot(
            text: note.text,
            nsFont: note.nsFont,
            fontColor: Color.fromString(note.fontColor),
            noteColor: Color.fromString(note.color),
            contentMaxWidth: maxW,
            onGeometryUpdate: { reportedSize = $0 }
        )

        if hosting == nil {
            let h = NSHostingView(rootView: root)
            h.translatesAutoresizingMaskIntoConstraints = false
            h.sizingOptions = [.minSize, .intrinsicContentSize, .maxSize]

            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 8000, height: 8000),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.alphaValue = 0
            w.ignoresMouseEvents = true
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            w.contentView = h
            positionOffScreen(w)

            self.hosting = h
            self.window = w
            w.orderBack(nil)
        } else {
            hosting?.rootView = root
            window?.orderBack(nil)
        }

        guard let hosting else {
            finishOnce(note.text.sizeUsingFont(usingFont: note.nsFont))
            return
        }

        hosting.layoutSubtreeIfNeeded()

        // One run loop is not always enough for StructuredText; wait briefly so layout settles.
        // Prefer `intrinsicContentSize` after `layoutSubtreeIfNeeded()` over GeometryReader preferences:
        // preferences can reflect an early pass (e.g. narrow width) while intrinsic matches the final layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            guard !finished else { return }
            hosting.invalidateIntrinsicContentSize()
            hosting.layoutSubtreeIfNeeded()

            let intrinsic = hosting.intrinsicContentSize
            let intrinsicOK = intrinsic.width > 0 && intrinsic.height > 0
                && intrinsic.width != NSView.noIntrinsicMetric && intrinsic.height != NSView.noIntrinsicMetric
            let plainFallback = note.text.sizeUsingFont(usingFont: note.nsFont)

            if intrinsicOK {
                finishOnce(intrinsic)
            } else if reportedSize.width > 0, reportedSize.height > 0 {
                finishOnce(reportedSize)
            } else {
                finishOnce(plainFallback)
            }
        }
    }

    private func positionOffScreen(_ w: NSWindow) {
        guard let screen = NSScreen.screens.first else {
            w.setFrameOrigin(NSPoint(x: 20_000, y: 20_000))
            return
        }
        let r = screen.frame
        w.setFrame(NSRect(x: r.maxX + 2000, y: r.minY - 2000, width: 8000, height: 8000), display: false)
    }
}

// MARK: - Measurement view (matches ``NoteTextView`` markdown branch, without ``ScrollView``)

private struct MarkdownMeasureRoot: View {
    let text: String
    let nsFont: NSFont
    let fontColor: Color
    let noteColor: Color
    /// Caps line width so the measure view does not expand to the full off-screen window (which would distort width).
    let contentMaxWidth: CGFloat
    let onGeometryUpdate: (CGSize) -> Void

    var body: some View {
        StructuredText(text, parser: StickNoteMarkdownParser())
            .textual.textSelection(.enabled)
            .textual.structuredTextStyle(StickNoteStructuredTextStyle())
            .font(Font(nsFont))
            .foregroundStyle(fontColor)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            // Horizontal must hug intrinsic width so geometry width isn’t always `contentMaxWidth`
            // (unlike display mode, which uses maxWidth: .infinity to fill the window).
            .fixedSize(horizontal: true, vertical: true)
            .background(noteColor)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: MarkdownMeasuredSizeKey.self, value: geo.size)
                }
            }
            .onPreferenceChange(MarkdownMeasuredSizeKey.self) { size in
                guard size.width > 0, size.height > 0 else { return }
                onGeometryUpdate(size)
            }
            .id(text)
    }
}

private enum MarkdownMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let n = nextValue()
        if n != .zero {
            value = n
        }
    }
}
