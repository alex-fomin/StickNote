import AppKit
import Foundation
import Vision

/// On-device text recognition for embedded PNG image notes (``Note/imageData``).
enum ImageOCR {

    enum Failure: LocalizedError {
        case couldNotCreateCGImage

        var errorDescription: String? {
            switch self {
            case .couldNotCreateCGImage:
                return "Could not read the image for text recognition."
            }
        }
    }

    /// Runs Vision text recognition. Call from a background queue; results are not tied to any actor.
    static func recognizeText(from imageData: Data) throws -> String {
        guard let cgImage = cgImage(fromPNGData: imageData) else {
            throw Failure.couldNotCreateCGImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        guard !observations.isEmpty else { return "" }

        return readingOrderStrings(from: observations).joined(separator: "\n")
    }

    private static func cgImage(fromPNGData data: Data) -> CGImage? {
        guard let nsImage = NSImage(data: data) else { return nil }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        if let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage
        else { return nil }
        return cg
    }

    /// Sorts observations for top-to-bottom, left-to-right reading in normalized Vision coordinates.
    private static func readingOrderStrings(from observations: [VNRecognizedTextObservation]) -> [String] {
        let lineTolerance: CGFloat = 0.02
        let sorted = observations.sorted { a, b in
            let ab = a.boundingBox
            let bb = b.boundingBox
            if abs(ab.midY - bb.midY) < lineTolerance {
                return ab.minX < bb.minX
            }
            return ab.maxY > bb.maxY
        }
        return sorted.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
    }
}
