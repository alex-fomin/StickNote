import AppKit
import SwiftUI

/// Non-editable image content for ``Note`` when ``Note/isImageNote`` is true.
struct NoteImageDisplay: View {
    let imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let ns = NSImage(data: data) {
                Image(nsImage: ns)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
