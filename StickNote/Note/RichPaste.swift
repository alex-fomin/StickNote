import AppKit
import UniformTypeIdentifiers

/// Clipboard HTML or RTF → Markdown. Plain text when the paste has no formatting.
/// ponytail: heading level is font-size vs body (AppKit drops h4–h6 and blockquotes). Tables are GFM only: colspan becomes empty cells, rowspan cells merge into their first row.
enum RichPaste {
    struct Content {
        var text: String
        var isMarkdown: Bool
    }

    static func content(from pasteboard: NSPasteboard = .general) -> Content? {
        #if DEBUG
        _ = didSelfCheck
        #endif
        for attr in attributedStrings(from: pasteboard) {
            if let markdown = markdown(from: attr) {
                return Content(text: markdown, isMarkdown: true)
            }
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return Content(text: text, isMarkdown: false)
        }
        return nil
    }

    #if DEBUG
    private static let didSelfCheck: Void = { selfCheck() }()

    static func selfCheck() {
        func convert(_ body: String) -> String? {
            let html = "<html><body>\(body)</body></html>"
            let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            let attr = try? NSAttributedString(data: Data(html.utf8), options: opts, documentAttributes: nil)
            return attr.flatMap { markdown(from: $0) }
        }
        func check(_ body: String, _ expected: String?) {
            let got = convert(body)
            assert(
                got == expected,
                "got [\(got ?? "nil")] expected [\(expected ?? "nil")] for \(body)")
        }
        check("<p>just text</p>", nil)
        check("<p>Hello <strong>bold</strong> and <em>italic</em></p>", "Hello **bold** and *italic*")
        check("<h1>Title</h1>", "# Title")
        check("<h2>Sub</h2><p>Body</p>", "## Sub\n\nBody")
        check("<ul><li>one</li><li>two</li></ul>", "- one\n- two")
        check("<ol><li>a</li><li>b</li></ol>", "1. a\n1. b")
        check("<p>see <a href=\"https://ex.com\">link</a></p>", "see [link](https://ex.com/)")
        check("<p>inline <code>code</code></p>", "inline `code`")
        check("<pre><code>line1\nline2</code></pre>", "```\nline1\nline2\n```")
        check("<ul><li>item <strong>bold</strong><ul><li>nested</li></ul></li></ul>", "- item **bold**\n  - nested")
        check("<p><del>strike</del></p>", "~~strike~~")
        check("<h3>Small</h3><p>Body</p>", "### Small\n\nBody")
        check("<p><strong>just bold</strong></p>", "**just bold**")
        check(
            "<table><tr><th>Name</th><th>Qty</th></tr><tr><td>Apple</td><td>2</td></tr><tr><td>Pear</td><td><strong>3</strong></td></tr></table>",
            "| Name | Qty |\n| --- | --- |\n| Apple | 2 |\n| Pear | **3** |"
        )
        check(
            "<p>before</p><table><tr><td>A</td><td>B</td></tr><tr><td>1</td><td>2</td></tr></table><p>after</p>",
            "before\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nafter"
        )
        check(
            "<table><tr><td>a|b</td><td><a href=\"https://ex.com\">x</a></td></tr></table>",
            "| a\\|b | [x](https://ex.com/) |\n| --- | --- |"
        )
        check(
            "<table><tr><td colspan=\"2\">wide</td><td>x</td></tr><tr><td>a</td><td>b</td><td>c</td></tr></table>",
            "| wide |  | x |\n| --- | --- | --- |\n| a | b | c |"
        )
        check(
            "<table>\n<tr>\n<td>\nApple\n</td>\n<td>2</td>\n</tr>\n</table>",
            "| Apple | 2 |\n| --- | --- |"
        )
        let rtf = "{\\rtf1\\ansi\\trowd\\cellx2000\\cellx4000\\intbl Name\\cell Qty\\cell\\row\\trowd\\cellx2000\\cellx4000\\intbl Apple\\cell 2\\cell\\row}"
        let rtfAttr = try? NSAttributedString(
            data: Data(rtf.utf8),
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil)
        assert(
            rtfAttr.flatMap { markdown(from: $0) }
                == "| Name | Qty |\n| --- | --- |\n| Apple | 2 |",
            "rtf table")
    }
    #endif

    private static func attributedStrings(from pasteboard: NSPasteboard) -> [NSAttributedString] {
        let candidates: [(NSPasteboard.PasteboardType, NSAttributedString.DocumentType)] = [
            (NSPasteboard.PasteboardType(UTType.html.identifier), .html),
            (.rtfd, .rtfd),
            (.rtf, .rtf),
        ]
        var result: [NSAttributedString] = []
        for (type, docType) in candidates {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: docType,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            if let attr = try? NSAttributedString(data: data, options: opts, documentAttributes: nil),
                attr.length > 0
            {
                result.append(attr)
            }
        }
        return result
    }

    private static let listMarkerPrefix = try! NSRegularExpression(
        pattern:
            "^[\\t \u{00A0}]*(?:[\u{2022}\u{25E6}\u{25AA}\u{25B8}\u{25CF}\u{25CB}\u{25A0}\u{25A1}\u{2043}]|\\d+[.)]?)[\\t \u{00A0}]*"
    )

    private static func markdown(from attr: NSAttributedString) -> String? {
        let ns = attr.string as NSString
        guard ns.length > 0 else { return nil }
        let bodySize = bodyPointSize(attr)
        var blocks: [String] = []
        var listLines: [String] = []
        var listOrdered: Bool?
        var codeLines: [String] = []
        var tableCells: [(row: Int, column: Int, text: String, table: NSTextTable)] = []
        var formatted = false

        func flushList() {
            if !listLines.isEmpty {
                blocks.append(listLines.joined(separator: "\n"))
                listLines.removeAll()
            }
            listOrdered = nil
        }
        func flushCode() {
            if !codeLines.isEmpty {
                formatted = true
                blocks.append(fenced(codeLines))
                codeLines.removeAll()
            }
        }
        func flushTable() {
            if !tableCells.isEmpty {
                formatted = true
                if let table = gfmTable(tableCells) {
                    blocks.append(table)
                }
                tableCells.removeAll()
            }
        }

        var loc = 0
        while loc < ns.length {
            let para = ns.paragraphRange(for: NSRange(location: loc, length: 0))
            let content = droppingTrailingNewline(ns, para)
            defer { loc = para.location + para.length }
            if para.length == 0 { continue }
            if let cell = textTableBlock(attr, at: para.location) {
                flushCode()
                flushList()
                if let current = tableCells.first?.table, current !== cell.table {
                    flushTable()
                }
                // Header cells come back bold from HTML `<th>`; GFM already styles the first row.
                let raw = content.length == 0
                    ? ""
                    : renderInlines(
                        attr, ns, content, suppressBold: cell.startingRow == 0, formatted: &formatted)
                tableCells.append((
                    max(0, cell.startingRow),
                    max(0, cell.startingColumn),
                    tableCellText(raw),
                    cell.table
                ))
                continue
            }
            flushTable()
            if content.length == 0 { continue }

            let lists =
                (attr.attribute(.paragraphStyle, at: content.location, effectiveRange: nil)
                    as? NSParagraphStyle)?.textLists ?? []
            if let list = lists.last {
                flushCode()
                let ordered = isOrdered(list)
                if let listOrdered, listOrdered != ordered { flushList() }
                listOrdered = ordered
                let body = strippingListMarker(ns, content)
                let text = neutralize(renderInlines(attr, ns, body, suppressBold: false, formatted: &formatted))
                let indent = String(repeating: "  ", count: max(0, lists.count - 1))
                let marker = ordered ? "1. " : "- "
                listLines.append(indent + marker + text)
                formatted = true
                continue
            }
            if allText(attr, ns, content, has: .monoSpace) {
                flushList()
                codeLines.append(
                    ns.substring(with: content).replacingOccurrences(of: "\u{2028}", with: "\n"))
                continue
            }
            flushList()
            flushCode()
            let level = headingLevel(attr, ns, content, bodySize: bodySize)
            var text = renderInlines(attr, ns, content, suppressBold: level != nil, formatted: &formatted)
            text = text.components(separatedBy: "\n").map { neutralize($0) }.joined(separator: "\n")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let level {
                formatted = true
                blocks.append(String(repeating: "#", count: level) + " " + trimmed)
            } else {
                blocks.append(trimmed)
            }
        }
        flushList()
        flushCode()
        flushTable()
        guard formatted else { return nil }
        let text = blocks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func headingLevel(
        _ attr: NSAttributedString, _ ns: NSString, _ range: NSRange, bodySize: CGFloat
    ) -> Int? {
        guard range.length > 0, bodySize > 0, allText(attr, ns, range, has: .bold) else { return nil }
        let size = dominantPointSize(attr, ns, range)
        let ratio = size / bodySize
        if ratio >= 1.85 { return 1 }
        if ratio >= 1.35 { return 2 }
        if ratio >= 1.12 { return 3 }
        if abs(ratio - 1) < 0.08 {
            if size >= 22 { return 1 }
            if size >= 17 { return 2 }
        }
        return nil
    }

    private static func bodyPointSize(_ attr: NSAttributedString) -> CGFloat {
        let ns = attr.string as NSString
        var nonBold: [Int: Int] = [:]
        var any: [Int: Int] = [:]
        var i = 0
        while i < ns.length {
            let ch = ns.character(at: i)
            if isBreak(ch) {
                i += 1
                continue
            }
            var run = NSRange()
            let font = attr.attributes(at: i, effectiveRange: &run)[.font] as? NSFont
            let end = min(run.location + run.length, ns.length)
            let weight = max(1, end - i)
            let size = Int((font?.pointSize ?? 12).rounded())
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            if !traits.contains(.monoSpace) {
                any[size, default: 0] += weight
                if !traits.contains(.bold) {
                    nonBold[size, default: 0] += weight
                }
            }
            i = max(end, i + 1)
        }
        let source = nonBold.isEmpty ? any : nonBold
        return CGFloat(source.max(by: { $0.value < $1.value })?.key ?? 12)
    }

    private static func dominantPointSize(_ attr: NSAttributedString, _ ns: NSString, _ range: NSRange) -> CGFloat {
        var counts: [Int: Int] = [:]
        var i = range.location
        let end = range.location + range.length
        while i < end {
            if isBreak(ns.character(at: i)) {
                i += 1
                continue
            }
            var run = NSRange()
            let font = attr.attributes(at: i, effectiveRange: &run)[.font] as? NSFont
            let runEnd = min(run.location + run.length, end)
            let size = Int((font?.pointSize ?? 12).rounded())
            counts[size, default: 0] += max(1, runEnd - i)
            i = max(runEnd, i + 1)
        }
        return CGFloat(counts.max(by: { $0.value < $1.value })?.key ?? 12)
    }

    /// True when every non-break character in `range` uses a font with `trait`.
    private static func allText(
        _ attr: NSAttributedString, _ ns: NSString, _ range: NSRange, has trait: NSFontDescriptor.SymbolicTraits
    ) -> Bool {
        var saw = false
        var i = range.location
        let end = range.location + range.length
        while i < end {
            if isBreak(ns.character(at: i)) {
                i += 1
                continue
            }
            saw = true
            var run = NSRange()
            let font = attr.attributes(at: i, effectiveRange: &run)[.font] as? NSFont
            if !(font?.fontDescriptor.symbolicTraits ?? []).contains(trait) { return false }
            i = max(min(run.location + run.length, end), i + 1)
        }
        return saw
    }

    private static func renderInlines(
        _ attr: NSAttributedString,
        _ ns: NSString,
        _ range: NSRange,
        suppressBold: Bool,
        formatted: inout Bool
    ) -> String {
        var result = ""
        var i = range.location
        let end = range.location + range.length
        while i < end {
            let ch = ns.character(at: i)
            if isBreak(ch) {
                result.append("\n")
                i += 1
                continue
            }
            var run = NSRange()
            let attrs = attr.attributes(at: i, effectiveRange: &run)
            var j = i
            let runEnd = min(run.location + run.length, end)
            while j < runEnd, !isBreak(ns.character(at: j)) { j += 1 }
            if j == i {
                i += 1
                continue
            }
            let piece = ns.substring(with: NSRange(location: i, length: j - i))
            let font = attrs[.font] as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let link = linkString(attrs[.link])
            let bold = !suppressBold && traits.contains(.bold)
            let italic = traits.contains(.italic)
            let code = traits.contains(.monoSpace)
            let strike = isStruck(attrs)
            if bold || italic || code || strike || link != nil { formatted = true }
            var wrapped = code ? codeSpan(piece) : escapeMarkdown(piece)
            if strike { wrapped = "~~\(wrapped)~~" }
            if italic { wrapped = "*\(wrapped)*" }
            if bold { wrapped = "**\(wrapped)**" }
            if let link { wrapped = "[\(wrapped)](\(escapeLink(link)))" }
            result.append(wrapped)
            i = j
        }
        return result
    }

    private static func strippingListMarker(_ ns: NSString, _ range: NSRange) -> NSRange {
        guard range.length > 0 else { return range }
        let sub = ns.substring(with: range)
        let full = NSRange(location: 0, length: (sub as NSString).length)
        guard let match = listMarkerPrefix.firstMatch(in: sub, range: full), match.range.length > 0 else {
            return range
        }
        let cut = match.range.length
        return NSRange(location: range.location + cut, length: range.length - cut)
    }

    private static func droppingTrailingNewline(_ ns: NSString, _ range: NSRange) -> NSRange {
        var range = range
        while range.length > 0 {
            let ch = ns.character(at: range.location + range.length - 1)
            if ch == 10 || ch == 13 {
                range.length -= 1
            } else {
                break
            }
        }
        return range
    }

    private static func isOrdered(_ list: NSTextList) -> Bool {
        let raw = list.markerFormat.rawValue
        return raw.contains("decimal") || raw.contains("alpha") || raw.contains("roman")
    }

    private static func isBreak(_ ch: unichar) -> Bool {
        ch == 10 || ch == 13 || ch == 0x2028 || ch == 0x2029
    }

    private static func isStruck(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        if let n = attrs[.strikethroughStyle] as? Int { return n != 0 }
        if let n = attrs[.strikethroughStyle] as? NSNumber { return n.intValue != 0 }
        return false
    }

    private static func linkString(_ value: Any?) -> String? {
        if let url = value as? URL { return url.absoluteString }
        if let text = value as? String, !text.isEmpty { return text }
        return nil
    }

    private static func escapeLink(_ url: String) -> String {
        url.replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
    }

    private static func escapeMarkdown(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            if "\\`*_[]~".contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    private static func codeSpan(_ text: String) -> String {
        text.contains("`") ? "`` \(text) ``" : "`\(text)`"
    }

    private static func fenced(_ lines: [String]) -> String {
        let body = lines.joined(separator: "\n")
        let fence = body.contains("```") ? "````" : "```"
        return "\(fence)\n\(body)\n\(fence)"
    }

    private static func tableCellText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "|", with: "\\|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func gfmTable(
        _ cells: [(row: Int, column: Int, text: String, table: NSTextTable)]
    ) -> String? {
        guard
            let minRow = cells.map(\.row).min(),
            let maxRow = cells.map(\.row).max(),
            let maxCol = cells.map(\.column).max(),
            cells.contains(where: { !$0.text.isEmpty })
        else { return nil }
        var grid = Array(
            repeating: Array(repeating: "", count: maxCol + 1),
            count: maxRow - minRow + 1)
        for cell in cells where !cell.text.isEmpty {
            let row = cell.row - minRow
            grid[row][cell.column] += grid[row][cell.column].isEmpty ? cell.text : "<br>" + cell.text
        }
        let lines = grid.map { "| " + $0.joined(separator: " | ") + " |" }
        let separator = "| " + Array(repeating: "---", count: maxCol + 1).joined(separator: " | ") + " |"
        return ([lines[0], separator] + lines.dropFirst()).joined(separator: "\n")
    }

    private static func textTableBlock(_ attr: NSAttributedString, at location: Int) -> NSTextTableBlock? {
        guard location < attr.length else { return nil }
        let style = attr.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        return style?.textBlocks.compactMap { $0 as? NSTextTableBlock }.first
    }

    private static let blockMarkerPrefix = try! NSRegularExpression(pattern: #"^(\s*)([-*+]|\d+\.)(\s)"#)

    /// Escapes a leading `#`, `-`, or `1.` so pasted prose doesn't turn into a heading or list.
    private static func neutralize(_ line: String) -> String {
        if line.hasPrefix("#") { return "\\" + line }
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = blockMarkerPrefix.firstMatch(in: line, options: [], range: full) else { return line }
        let marker = m.range(at: 2)
        return ns.substring(to: marker.location) + "\\" + ns.substring(from: marker.location)
    }
}
