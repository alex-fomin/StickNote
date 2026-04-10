import AppKit
import SwiftUI

/// Non-editable image content for ``Note`` when ``Note/isImageNote`` is true.
/// ``Note/imageData`` is never modified; Cmd+/Cmd- resizes the window so the image fits a larger or smaller frame.
struct NoteImageDisplay: View {
    let imageData: Data?

    /// Matches ``NoteLayout.defaultLayout`` body size (used for list preview scaling vs. window zoom).
    static let referenceFontSize: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            Group {
                if let data = imageData, let ns = NSImage(data: data) {
                    Image(nsImage: ns)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
