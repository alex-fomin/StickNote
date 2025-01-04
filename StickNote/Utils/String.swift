extension String {
    public func truncate(_ maxLength: Int) -> String {
        if self.count == 0 {
            return self
        }

        let lines = self.split(separator: "\n", maxSplits: 2)
        let firstLine = lines.first!
        let needElipses = lines.count > 1 || firstLine.count > maxLength

        var result = firstLine.prefix(maxLength)
        if needElipses {
            result = result + "…"
        }
        return String(result)
    }
}



