import AppKit
import UniformTypeIdentifiers

/// Clipboard HTML or RTF → Markdown. Plain text when the paste has no formatting.
/// ponytail: heading level is font-size vs body (AppKit drops h4–h6 and blockquotes). Tables are GFM only: colspan becomes empty cells, rowspan and nested tables are flattened.
enum RichPaste {
    struct Content {
        var text: String
        var isMarkdown: Bool
    }

    static func content(from pasteboard: NSPasteboard = .general) -> Content? {
        #if DEBUG
        _ = didSelfCheck
        #endif
        if let html = htmlString(from: pasteboard), let markdown = markdown(fromHTML: html) {
            return Content(text: markdown, isMarkdown: true)
        }
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
        func checkHTML(_ body: String, _ expected: String) {
            let got = markdown(fromHTML: "<html><body>\(body)</body></html>")
            assert(got == expected, "got [\(got ?? "nil")] expected [\(expected)] for \(body)")
        }
        checkHTML(
            "<table><tr><th>Name</th><th>Qty</th></tr><tr><td>Apple</td><td>2</td></tr><tr><td>Pear</td><td><strong>3</strong></td></tr></table>",
            "| Name | Qty |\n| --- | --- |\n| Apple | 2 |\n| Pear | **3** |"
        )
        checkHTML(
            "<p>before</p><table><tr><td>A</td><td>B</td></tr><tr><td>1</td><td>2</td></tr></table><p>after</p>",
            "before\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nafter"
        )
        checkHTML(
            "<table><tr><td>a|b</td><td><a href=\"https://ex.com\">x</a></td></tr></table>",
            "| a\\|b | [x](https://ex.com/) |\n| --- | --- |"
        )
        checkHTML(
            "<table><tr><td colspan=\"2\">wide</td><td>x</td></tr><tr><td>a</td><td>b</td><td>c</td></tr></table>",
            "| wide |  | x |\n| --- | --- | --- |\n| a | b | c |"
        )
        checkHTML(
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
                let raw = content.length == 0
                    ? ""
                    : renderInlines(attr, ns, content, suppressBold: false, formatted: &formatted)
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
            if isMonospace(attr, ns, content) {
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
        guard range.length > 0, bodySize > 0, isAllBold(attr, ns, range) else { return nil }
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

    private static func isAllBold(_ attr: NSAttributedString, _ ns: NSString, _ range: NSRange) -> Bool {
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
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            if !traits.contains(.bold) { return false }
            i = max(min(run.location + run.length, end), i + 1)
        }
        return saw
    }

    private static func isMonospace(_ attr: NSAttributedString, _ ns: NSString, _ range: NSRange) -> Bool {
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
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            if !traits.contains(.monoSpace) { return false }
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

    private static func tableToken(_ index: Int) -> String {
        "STICKNOTETABLE\(index)"
    }

    private static func htmlString(from pasteboard: NSPasteboard) -> String? {
        let type = NSPasteboard.PasteboardType(UTType.html.identifier)
        guard let data = pasteboard.data(forType: type), !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func attributedHTML(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let attr = try? NSAttributedString(data: data, options: opts, documentAttributes: nil),
            attr.length > 0
        else { return nil }
        return attr
    }

    private static func markdown(fromHTML html: String) -> String? {
        let extracted = extractHTMLTables(from: html)
        guard let attr = attributedHTML(extracted.html) else {
            guard !extracted.tables.isEmpty else { return nil }
            return extracted.tables.joined(separator: "\n\n")
        }
        let base = markdown(from: attr) ?? (extracted.tables.isEmpty ? nil : attr.string)
        guard let base else { return nil }
        let spliced = spliceTables(base, extracted.tables)
        return spliced.isEmpty ? nil : spliced
    }

    private static func extractHTMLTables(from html: String) -> (html: String, tables: [String]) {
        var output = ""
        var tables: [String] = []
        var index = html.startIndex
        while index < html.endIndex {
            guard let open = elementOpen(html, name: "table", from: index) else {
                output.append(contentsOf: html[index...])
                break
            }
            output.append(contentsOf: html[index..<open.tagStart])
            guard let close = elementClose(html, name: "table", from: open.contentStart) else {
                output.append(contentsOf: html[open.tagStart...])
                break
            }
            let inner = String(html[open.contentStart..<close.contentEnd])
            if let table = gfmRows(htmlTableRows(inner)) {
                output.append("<p>\(tableToken(tables.count))</p>")
                tables.append(table)
            } else {
                output.append(contentsOf: html[open.tagStart..<close.tagEnd])
            }
            index = close.tagEnd
        }
        return (output, tables)
    }

    private static func spliceTables(_ text: String, _ tables: [String]) -> String {
        var text = text
        for (index, table) in tables.enumerated() {
            text = text.replacingOccurrences(of: tableToken(index), with: "\n\n\(table)\n\n")
        }
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlTableRows(_ inner: String) -> [[String]] {
        let flat = removeNestedElements(inner, name: "table")
        var rows: [[String]] = []
        var index = flat.startIndex
        while index < flat.endIndex {
            guard let open = elementOpen(flat, name: "tr", from: index) else { break }
            guard let close = elementClose(flat, name: "tr", from: open.contentStart) else { break }
            let rowHTML = String(flat[open.contentStart..<close.contentEnd])
            let cells = htmlRowCells(rowHTML)
            if !cells.isEmpty { rows.append(cells) }
            index = close.tagEnd
        }
        return rows
    }

    private static func htmlRowCells(_ rowHTML: String) -> [String] {
        var cells: [String] = []
        var index = rowHTML.startIndex
        while index < rowHTML.endIndex {
            guard let tag = nextCellOpen(rowHTML, from: index) else { break }
            let end = endOfCell(rowHTML, from: tag.tagEnd)
            let fragment = String(rowHTML[tag.tagEnd..<end])
            cells.append(tableCellText(cellMarkdown(fromHTML: fragment)))
            let span = min(20, max(1, colspan(tag.attributes)))
            if span > 1 {
                cells.append(contentsOf: Array(repeating: "", count: span - 1))
            }
            index = end
        }
        return cells
    }

    private static func cellMarkdown(fromHTML fragment: String) -> String {
        let html = "<html><body>\(fragment)</body></html>"
        guard let attr = attributedHTML(html) else { return fragment }
        let ns = attr.string as NSString
        let content = droppingTrailingNewline(ns, NSRange(location: 0, length: attr.length))
        if content.length == 0 { return "" }
        var formatted = false
        return renderInlines(attr, ns, content, suppressBold: false, formatted: &formatted)
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
        gfmRows(cells.map { ($0.row, $0.column, $0.text) })
    }

    private static func gfmRows(_ cells: [(row: Int, column: Int, text: String)]) -> String? {
        guard !cells.isEmpty else { return nil }
        let minRow = cells.map(\.row).min() ?? 0
        let maxRow = cells.map(\.row).max() ?? 0
        let maxCol = cells.map(\.column).max() ?? 0
        guard maxCol >= 0, maxRow >= minRow else { return nil }
        var grid = Array(
            repeating: Array(repeating: "", count: maxCol + 1),
            count: maxRow - minRow + 1)
        for cell in cells {
            let row = cell.row - minRow
            let column = cell.column
            guard grid.indices.contains(row), grid[row].indices.contains(column) else { continue }
            if grid[row][column].isEmpty {
                grid[row][column] = cell.text
            } else if !cell.text.isEmpty {
                grid[row][column] += "<br>" + cell.text
            }
        }
        return gfmRows(grid)
    }

    private static func gfmRows(_ rows: [[String]]) -> String? {
        guard rows.contains(where: { $0.contains { !$0.isEmpty } }) else { return nil }
        let width = rows.map(\.count).max() ?? 0
        guard width > 0 else { return nil }
        func line(_ row: [String]) -> String {
            let padded = row + Array(repeating: "", count: max(0, width - row.count))
            return "| " + padded.joined(separator: " | ") + " |"
        }
        let separator = "| " + Array(repeating: "---", count: width).joined(separator: " | ") + " |"
        return ([line(rows[0]), separator] + rows.dropFirst().map(line)).joined(separator: "\n")
    }

    private static func textTableBlock(_ attr: NSAttributedString, at location: Int) -> NSTextTableBlock? {
        guard location < attr.length else { return nil }
        let style = attr.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        return style?.textBlocks.compactMap { $0 as? NSTextTableBlock }.first
    }

    private struct HTMLTag {
        var name: String
        var isClose: Bool
        var attributes: String
        var tagStart: String.Index
        var tagEnd: String.Index
    }

    private struct ElementSpan {
        var tagStart: String.Index
        var contentStart: String.Index
        var contentEnd: String.Index
        var tagEnd: String.Index
    }

    private static func elementOpen(_ html: String, name: String, from index: String.Index) -> ElementSpan? {
        var cursor = index
        while let tag = nextTag(html, from: cursor) {
            if tag.name == name, !tag.isClose {
                return ElementSpan(
                    tagStart: tag.tagStart, contentStart: tag.tagEnd, contentEnd: tag.tagEnd, tagEnd: tag.tagEnd)
            }
            cursor = tag.tagEnd
        }
        return nil
    }

    private static func elementClose(_ html: String, name: String, from index: String.Index) -> ElementSpan? {
        var depth = 1
        var cursor = index
        while let tag = nextTag(html, from: cursor) {
            if tag.name == name {
                if tag.isClose {
                    depth -= 1
                    if depth == 0 {
                        return ElementSpan(
                            tagStart: tag.tagStart, contentStart: index, contentEnd: tag.tagStart, tagEnd: tag.tagEnd)
                    }
                } else {
                    depth += 1
                }
            }
            cursor = tag.tagEnd
        }
        return nil
    }

    private static func removeNestedElements(_ html: String, name: String) -> String {
        var output = ""
        var index = html.startIndex
        while index < html.endIndex {
            guard let open = elementOpen(html, name: name, from: index) else {
                output.append(contentsOf: html[index...])
                break
            }
            output.append(contentsOf: html[index..<open.tagStart])
            guard let close = elementClose(html, name: name, from: open.contentStart) else {
                output.append(contentsOf: html[open.tagStart...])
                break
            }
            output.append(stripTags(String(html[open.contentStart..<close.contentEnd])))
            index = close.tagEnd
        }
        return output
    }

    private static func nextCellOpen(_ html: String, from index: String.Index) -> HTMLTag? {
        var cursor = index
        while let tag = nextTag(html, from: cursor) {
            if !tag.isClose, tag.name == "td" || tag.name == "th" { return tag }
            cursor = tag.tagEnd
        }
        return nil
    }

    private static func endOfCell(_ html: String, from index: String.Index) -> String.Index {
        var cursor = index
        while let tag = nextTag(html, from: cursor) {
            if tag.isClose, tag.name == "td" || tag.name == "th" || tag.name == "tr" {
                return tag.tagStart
            }
            if !tag.isClose, tag.name == "td" || tag.name == "th" {
                return tag.tagStart
            }
            cursor = tag.tagEnd
        }
        return html.endIndex
    }

    private static func colspan(_ attributes: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"colspan\s*=\s*"?(\d+)"?"#, options: [.caseInsensitive])
        else { return 1 }
        let range = NSRange(attributes.startIndex..., in: attributes)
        guard let match = regex.firstMatch(in: attributes, range: range),
            let valueRange = Range(match.range(at: 1), in: attributes),
            let value = Int(attributes[valueRange])
        else { return 1 }
        return value
    }

    private static func nextTag(_ html: String, from index: String.Index) -> HTMLTag? {
        var i = index
        while i < html.endIndex {
            guard html[i] == "<" else {
                i = html.index(after: i)
                continue
            }
            let start = i
            var j = html.index(after: i)
            if j < html.endIndex, html[j] == "!" {
                if let end = html.range(of: "-->", range: j..<html.endIndex) {
                    i = end.upperBound
                    continue
                }
                return nil
            }
            var isClose = false
            if j < html.endIndex, html[j] == "/" {
                isClose = true
                j = html.index(after: j)
            }
            let nameStart = j
            while j < html.endIndex, html[j].isLetter || html[j].isNumber {
                j = html.index(after: j)
            }
            guard j > nameStart else {
                i = html.index(after: i)
                continue
            }
            let name = html[nameStart..<j].lowercased()
            let attrStart = j
            var quote: Character?
            while j < html.endIndex {
                let ch = html[j]
                if let openQuote = quote {
                    if ch == openQuote { quote = nil }
                } else if ch == "\"" || ch == "'" {
                    quote = ch
                } else if ch == ">" {
                    let tagEnd = html.index(after: j)
                    return HTMLTag(
                        name: name,
                        isClose: isClose,
                        attributes: String(html[attrStart..<j]),
                        tagStart: start,
                        tagEnd: tagEnd)
                }
                j = html.index(after: j)
            }
            return nil
        }
        return nil
    }

    private static func stripTags(_ html: String) -> String {
        var output = ""
        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<", let tag = nextTag(html, from: index) {
                if tag.name == "br" { output.append(" ") }
                index = tag.tagEnd
                continue
            }
            output.append(html[index])
            index = html.index(after: index)
        }
        return output
    }

    private static func neutralize(_ line: String) -> String {
        if line.hasPrefix("#") { return "\\" + line }
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard
            let match = try? NSRegularExpression(pattern: #"^(\s*)([-*+]|\d+\.)(\s)"#),
            let m = match.firstMatch(in: line, options: [], range: full)
        else { return line }
        let marker = m.range(at: 2)
        return ns.substring(to: marker.location) + "\\" + ns.substring(from: marker.location)
    }
}
