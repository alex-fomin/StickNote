import AppKit

extension String {
    public func truncate(_ maxLength: Int) -> String {
        if self.count == 0 {
            return self
        }

        let lines = self.split(separator: "\n", maxSplits: 2)
        let firstLine = lines.first ?? ""
        let needElipses = lines.count > 1 || firstLine.count > maxLength

        var result = firstLine.prefix(maxLength)
        if needElipses {
            result = result + "…"
        }
        return String(result)
    }

    func sizeUsingFont(usingFont font: NSFont) -> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: fontAttributes)
    }
}
