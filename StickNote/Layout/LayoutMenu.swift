import AppKit
import SwiftData
import SwiftUI

struct LayoutMenu: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \NoteLayout.name) var layouts: [NoteLayout]

    @Binding var note: Note
    /// When set with more than one note, choosing a layout applies it to each note (multi-selected floating notes).
    var bulkApplyTargets: [Note]? = nil

    private var notesToApplyLayout: [Note] {
        if let bulk = bulkApplyTargets, bulk.count > 1 { return bulk }
        return [note]
    }

    var body: some View {
        Group {
            ForEach(layouts.sorted { a, b in a.isDefault }, id: \.self) { layout in
                let sameLayout = notesToApplyLayout.allSatisfy { $0.isSameAppearance(layout) }
                Toggle(isOn: Binding(
                    get: { sameLayout },
                    set: { _ in
                        for n in notesToApplyLayout {
                            n.apply(layout: layout)
                        }
                    }
                )) {
                    // The menu icon slot is templated and drops the fill. An image inside the title keeps the color.
                    layoutTitle(layout)
                }
            }
            Divider()
            Button("Custom...") {
                openWindow(value: note.persistentModelID)
            }
        }
    }

    private func layoutTitle(_ layout: NoteLayout) -> Text {
        let swatch = Image(nsImage: LayoutMenuSwatch.image(
            storedBgHex: layout.color,
            isDark: colorScheme == .dark
        ))
        return Text("\(swatch) \(layout.name)")
    }
}

/// Pixels, not a symbol: AppKit menu items retint template images and the color disappears.
enum LayoutMenuSwatch {
    static func image(storedBgHex: String, isDark: Bool) -> NSImage {
        let color = NoteDisplayColors.displayBackgroundNSColor(storedBgHex: storedBgHex, isDark: isDark)
        let points: CGFloat = 12
        let scale: CGFloat = 2
        let pixels = Int(points * scale)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixels,
                pixelsHigh: pixels,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return NSImage()
        }
        rep.size = NSSize(width: points, height: points)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0.5, y: 0.5, width: points - 1, height: points - 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        color.setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 1
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: points, height: points))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
}

#Preview {
    LayoutMenu(note: .constant(Note(layout: NoteLayout.defaultLayout, text: "note")))
}
