import AppKit

/// Default width for ``String.wrappingLongLinesAtWordBoundaries()`` in plain-text notes.
enum NoteLineWrap {
    /// Hard-wrap lines longer than this at spaces; long unbroken tokens stay on one line.
    static let maxCharactersPerLine = 80
}

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

    /// Trims plain-text notes: a single line is trimmed at both ends. For multiple lines, trailing
    /// whitespace is removed from every line; the first line that has leading whitespace defines `n`,
    /// and each following line has at most `n` leading whitespace characters removed from its start.
    func trimmingNoteWhitespace() -> String {
        if isEmpty { return self }
        let lines = components(separatedBy: "\n")
        if lines.count == 1 {
            return lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let refIdx = lines.firstIndex(where: { $0.leadingWhitespaceCount > 0 }) else {
            return lines.map { $0.removingTrailingWhitespaceFromLine() }.joined(separator: "\n")
        }
        let n = lines[refIdx].leadingWhitespaceCount
        return lines.enumerated().map { index, line in
            let withoutLeadingDeduction = index > refIdx ? line.removingLeadingWhitespace(upTo: n) : line
            return withoutLeadingDeduction.removingTrailingWhitespaceFromLine()
        }.joined(separator: "\n")
    }

    /// Wraps each line that exceeds `maxCharactersPerLine` by breaking only at whitespace between words.
    /// Runs of spaces collapse to single spaces inside wrapped segments; lines already short enough are unchanged.
    func wrappingLongLinesAtWordBoundaries(maxCharactersPerLine: Int = NoteLineWrap.maxCharactersPerLine) -> String {
        guard maxCharactersPerLine > 0 else { return self }
        return components(separatedBy: "\n").map { $0.wrappingSingleLineAtWordBoundaries(maxCharactersPerLine: maxCharactersPerLine) }.joined(separator: "\n")
    }

    private func wrappingSingleLineAtWordBoundaries(maxCharactersPerLine: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return self }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return self }

        var lines: [String] = []
        var current = ""

        func appendLine(_ line: String) {
            if !line.isEmpty { lines.append(line) }
        }

        for word in words {
            if word.count > maxCharactersPerLine {
                appendLine(current)
                current = ""
                lines.append(word)
                continue
            }
            if current.isEmpty {
                current = word
                continue
            }
            if current.count + 1 + word.count <= maxCharactersPerLine {
                current += " " + word
            } else {
                appendLine(current)
                current = word
            }
        }
        appendLine(current)
        return lines.joined(separator: "\n")
    }

    fileprivate var leadingWhitespaceCount: Int {
        var count = 0
        for ch in self {
            guard ch.isWhitespace else { break }
            count += 1
        }
        return count
    }

    fileprivate func removingLeadingWhitespace(upTo maxCount: Int) -> String {
        guard maxCount > 0 else { return self }
        var remaining = maxCount
        var result = self
        while remaining > 0, let first = result.first, first.isWhitespace {
            result.removeFirst()
            remaining -= 1
        }
        return result
    }

    fileprivate func removingTrailingWhitespaceFromLine() -> String {
        var result = self
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }
        return result
    }

}
