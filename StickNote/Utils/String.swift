import AppKit

extension String {
    public func truncate(_ maxLength: Int, maxLines: Int = 1) -> String {
        if self.count == 0 {
            return self
        }

        let lines = self.split(separator: "\n", maxSplits: maxLines + 1)
        let firstLine = lines.prefix(maxLines).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.joined(separator: "… ")
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

    func removeTrailingEmptyLines() -> String {
        let pattern = "(?m)\\s*\\n\\z"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
    }

}
