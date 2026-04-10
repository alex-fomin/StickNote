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
    /// - Parameter contentMaxWidth: When the note already has a width, pass the inner content width so wrapping matches the real window; otherwise a large default is used (same idea as unbounded string sizing).
    func measure(note: Note, contentMaxWidth: CGFloat?, completion: @escaping @MainActor (CGSize) -> Void) {
        var finished = false
        let finishOnce: @MainActor (CGSize) -> Void = { size in
            guard !finished else { return }
            finished = true
            let w = max(20, size.width)
            let h = max(1, size.height)
            completion(CGSize(width: w, height: h))
        }

        let maxW = contentMaxWidth.map { max(1, $0) } ?? 10_000

        let root = MarkdownMeasureRoot(
            text: note.text,
            nsFont: note.nsFont,
            fontColor: Color.fromString(note.fontColor),
            noteColor: Color.fromString(note.color),
            contentMaxWidth: maxW,
            onMeasured: { size in
                finishOnce(size)
            }
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

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            hosting.invalidateIntrinsicContentSize()
            hosting.layoutSubtreeIfNeeded()
            let intrinsic = hosting.intrinsicContentSize
            if intrinsic.width > 0, intrinsic.height > 0,
                intrinsic.width != NSView.noIntrinsicMetric, intrinsic.height != NSView.noIntrinsicMetric
            {
                finishOnce(intrinsic)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            guard !finished else { return }
            hosting.layoutSubtreeIfNeeded()
            let intrinsic = hosting.intrinsicContentSize
            if intrinsic.width > 0, intrinsic.height > 0,
                intrinsic.width != NSView.noIntrinsicMetric, intrinsic.height != NSView.noIntrinsicMetric
            {
                finishOnce(intrinsic)
                return
            }
            finishOnce(note.text.sizeUsingFont(usingFont: note.nsFont))
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
    let onMeasured: (CGSize) -> Void

    @State private var didReport = false

    var body: some View {
        StructuredText(text, parser: StickNoteMarkdownParser())
            .textual.textSelection(.enabled)
            .textual.structuredTextStyle(StickNoteStructuredTextStyle())
            .font(Font(nsFont))
            .foregroundStyle(fontColor)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(noteColor)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: MarkdownMeasuredSizeKey.self, value: geo.size)
                }
            }
            .onPreferenceChange(MarkdownMeasuredSizeKey.self) { size in
                guard !didReport, size.width > 0, size.height > 0 else { return }
                didReport = true
                onMeasured(size)
            }
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
