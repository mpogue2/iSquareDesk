import Foundation

struct CuesheetMatchResult {
    let url: URL
    let displayName: String
    let score: Int
}

final class CuesheetMatcher {
    private let musicRoot: URL
    private var labelNameToIDs: [String: [String]] = [:] // lowercased labelID -> [label names]
    private var pathStackCuesheets: [(type: String, url: URL)] = []

    init(musicRoot: URL) {
        self.musicRoot = musicRoot
        self.loadLabelMap()
    }

    func buildPathStackCuesheets() {
        pathStackCuesheets.removeAll()
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: musicRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "html" || url.pathExtension.lowercased() == "htm" {
                // Determine type: prefer top-level folder name if under musicRoot
                let relative = url.path.replacingOccurrences(of: musicRoot.path, with: "")
                let comps = relative.split(separator: "/").map(String.init)
                let type = comps.first?.lowercased() ?? ""
                pathStackCuesheets.append((type: type, url: url))
            }
        }
    }

    func betterFindPossibleCuesheets(songFile: URL) -> [CuesheetMatchResult] {
        let fileCategory = filepath2SongCategoryName(songFile)
        let fileCategoryIsPatter = (fileCategory == "patter")
        let mp3CompleteBaseName = songFile.deletingPathExtension().lastPathComponent

        var results: [CuesheetMatchResult] = []
        for entry in pathStackCuesheets {
            if fileCategoryIsPatter && entry.type == "lyrics" { continue }
            let cuesheetBase = entry.url.deletingPathExtension().lastPathComponent
            let score = MP3FilenameVsCuesheetnameScore(fn: mp3CompleteBaseName, cn: cuesheetBase)
            if score > 0 {
                let displayName = displayNameFor(url: entry.url)
                results.append(CuesheetMatchResult(url: entry.url, displayName: displayName, score: score))
            }
        }

        // Sort descending by score, then by name for stability
        results.sort { (a, b) in
            if a.score != b.score { return a.score > b.score }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        return results
    }

    func loadCuesheets(songFile: URL, songType: String, lastCuesheetAbsolutePath: String?) -> (items: [String], selectedIndex: Int?, matches: [CuesheetMatchResult]) {
        let matches = betterFindPossibleCuesheets(songFile: songFile)
        let items = matches.map { $0.displayName }
        guard !matches.isEmpty else { return ([], nil, matches) }

        // Select last_cuesheet if present (map to current root), else select highest score (index 0)
        if let lastAbs = lastCuesheetAbsolutePath, !lastAbs.isEmpty {
            let translated = convertCuesheetPathNameToCurrentRoot(lastAbs)
            if let idx = matches.firstIndex(where: { compareCuesheetPathNamesRelative($0.url.path, translated) }) {
                return (items, idx, matches)
            }
        }
        return (items, 0, matches)
    }

    // MARK: - Helpers

    private func displayNameFor(url: URL) -> String {
        let path = url.path
        let root = musicRoot.path.hasSuffix("/") ? musicRoot.path : musicRoot.path + "/"
        if path.hasPrefix(root) {
            return String(path.dropFirst(root.count))
        }
        return url.lastPathComponent
    }

    private func filepath2SongCategoryName(_ url: URL) -> String {
        let relative = url.path.replacingOccurrences(of: musicRoot.path, with: "")
        if let first = relative.split(separator: "/").first {
            return String(first).lowercased()
        }
        return ""
    }

    private func loadLabelMap() {
        // Try to load Resources/squareDanceLabelIDs.csv alongside app bundle structure used in repo
        // Format: name,pitch,ID (we use indices 0 and 2 based on the Qt code comment)
        let repoResources = musicRoot.deletingLastPathComponent().appendingPathComponent("Resources/squareDanceLabelIDs.csv")
        let fm = FileManager.default
        guard fm.fileExists(atPath: repoResources.path) else { return }
        do {
            let content = try String(contentsOf: repoResources, encoding: .utf8)
            for line in content.split(separator: "\n") {
                let s = String(line)
                if s.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                // Basic CSV split: the repo file likely simple, but avoid breaking on commas inside quotes by a light parser
                let fields = parseCSVLine(s)
                if fields.count == 3 {
                    let name = fields[0].lowercased()
                    let id = fields[2].lowercased()
                    if id != "?" && !name.isEmpty && !id.isEmpty {
                        labelNameToIDs[id, default: []].append(name)
                    }
                }
            }
        } catch {
            // ignore missing file
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // Port of Qt compareCuesheetPathNamesRelative logic
    private func compareCuesheetPathNamesRelative(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let arr = Array(a)
        let brr = Array(b)
        let len1 = arr.count
        let len2 = brr.count
        let maxlen = min(len1, len2)
        var common = ""
        for i in 0..<maxlen {
            let c1 = arr[len1 - 1 - i]
            let c2 = brr[len2 - 1 - i]
            if c1 != c2 { break }
            common = String(c1) + common
        }
        if common.hasPrefix(".") { return false }
        if common.hasPrefix("/lyrics/") { return true }
        if common.hasPrefix("/singing/") { return true }
        if common.hasPrefix("/singers/") { return true }
        return false
    }

    // Port of Qt convertCuesheetPathNameToCurrentRoot logic (approximate)
    private func convertCuesheetPathNameToCurrentRoot(_ str: String) -> String {
        if str.isEmpty { return str }
        // If already under current root and exists, return it
        let strURL = URL(fileURLWithPath: str)
        if str.hasPrefix(musicRoot.path), FileManager.default.fileExists(atPath: strURL.path) {
            return str
        }
        // Peel prefix until we find a path under current root
        // Simple heuristic: find the suffix starting at /lyrics/ or /singing/ or /singers/
        let lower = str.lowercased()
        if let r = lower.range(of: "/lyrics/") ?? lower.range(of: "/singing/") ?? lower.range(of: "/singers/") {
            let suffix = String(str[r.lowerBound...])
            return musicRoot.appendingPathComponent(suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).path
        }
        // Fallback: just append last path component under lyrics
        return musicRoot.appendingPathComponent("lyrics").appendingPathComponent(strURL.lastPathComponent).path
    }

    // MARK: - Scoring function port
    private func MP3FilenameVsCuesheetnameScore(fn: String, cn: String) -> Int {
        // Step 1: remove parentheses and simplify whitespace
        func removeParentheses(_ s: String) -> String {
            var str = s
            // Remove text in parentheses repeatedly
            while let start = str.firstIndex(of: "("), let end = str[start...].firstIndex(of: ")") {
                str.removeSubrange(start...end)
            }
            return str.replacingOccurrences(of: "  ", with: " ")
        }

        func simplified(_ s: String) -> String {
            let comps = s.split(whereSeparator: { $0.isWhitespace })
            return comps.joined(separator: " ")
        }

        func fuzzyWordEqual(_ w1: String, _ w2: String) -> Bool {
            if w1.caseInsensitiveCompare(w2) == .orderedSame { return true }
            let a = Array(w1.lowercased())
            let b = Array(w2.lowercased())
            if abs(a.count - b.count) > 1 { return false }
            // Adjacent transposition check
            if a.count == b.count && a.count >= 2 {
                for i in 0..<(a.count - 1) {
                    var t = a
                    t.swapAt(i, i+1)
                    if String(t) == String(b) { return true }
                }
            }
            // Levenshtein distance <= 1
            return levenshteinDistance(a, b) <= 1
        }

        func labelWordEqual(_ w1: String, _ w2: String) -> Bool {
            let k1 = w1.lowercased()
            let k2 = w2.lowercased()
            if let vals = labelNameToIDs[k1], vals.contains(k2) { return true }
            if let vals2 = labelNameToIDs[k2], vals2.contains(k1) { return true }
            return false
        }

        func filterShortWords(_ words: [String]) -> [String] {
            return words.filter { $0.count > 2 }
        }

        func levenshteinDistance(_ a: [Character], _ b: [Character]) -> Int {
            let n = a.count, m = b.count
            if n == 0 { return m }
            if m == 0 { return n }
            var d = Array(repeating: Array(repeating: 0, count: m+1), count: n+1)
            for i in 0...n { d[i][0] = i }
            for j in 0...m { d[0][j] = j }
            for i in 1...n {
                for j in 1...m {
                    let cost = (a[i-1] == b[j-1]) ? 0 : 1
                    d[i][j] = min(
                        d[i-1][j] + 1,
                        d[i][j-1] + 1,
                        d[i-1][j-1] + cost
                    )
                    if i > 1 && j > 1 && a[i-1] == b[j-2] && a[i-2] == b[j-1] {
                        d[i][j] = min(d[i][j], d[i-2][j-2] + cost)
                    }
                }
            }
            return d[n][m]
        }

        // Preprocess
        var mp3Name = simplified(removeParentheses(fn))
        var cuesheetName = simplified(removeParentheses(cn))

        // Remove dot-number at end, e.g. Blue.2 or Blue.10
        if let r = cuesheetName.range(of: "\\.[0-9]+$", options: .regularExpression) {
            cuesheetName.removeSubrange(r)
        }

        // New Beat NB-303 -> NB 303 in both
        mp3Name = mp3Name.replacingOccurrences(of: "NB-([0-9]+)", with: "NB $1", options: .regularExpression)
        cuesheetName = cuesheetName.replacingOccurrences(of: "NB-([0-9]+)", with: "NB $1", options: .regularExpression)

        // Step 2: exact match
        if mp3Name.caseInsensitiveCompare(cuesheetName) == .orderedSame { return 100 }

        // Step 3: split words and filter short words
        let mp3AllWords = mp3Name.split{ $0.isWhitespace }.map(String.init)
        let csAllWords = cuesheetName.split{ $0.isWhitespace }.map(String.init)
        var mp3Words = filterShortWords(mp3AllWords)
        var csWords = filterShortWords(csAllWords)
        if mp3Words.isEmpty && !mp3AllWords.isEmpty { mp3Words = mp3AllWords }
        if csWords.isEmpty && !csAllWords.isEmpty { csWords = csAllWords }
        mp3Words.sort { $0.lowercased() < $1.lowercased() }
        csWords.sort { $0.lowercased() < $1.lowercased() }

        // Step 4: containment checks in order with fuzzy matching
        func containsAllInOrder(_ a: [String], _ b: [String]) -> Bool { // does b contain all of a in order
            var i = 0, j = 0
            while i < a.count && j < b.count {
                if fuzzyWordEqual(a[i], b[j]) { i += 1; j += 1 } else { j += 1 }
            }
            return i == a.count
        }
        let cuesheetContainsAllMp3 = containsAllInOrder(mp3Words, csWords) && mp3Words.count >= 2
        let mp3ContainsAllCuesheet = containsAllInOrder(csWords, mp3Words) && csWords.count >= 2
        if cuesheetContainsAllMp3 { return 95 }
        if mp3ContainsAllCuesheet { return 90 }

        // Step 5: parse components LABEL NUM[EXTRA] - TITLE or reversed
        struct ParsedName { var label = ""; var labelNum = ""; var labelExtra = ""; var title = "" }
        func parseFilename(_ name: String) -> ParsedName {
            let std = try? NSRegularExpression(pattern: "^([A-Za-z ]{1,20})\\s*([0-9]{1,5})([A-Za-z]{0,4})?\\s*-\\s*(.+)$", options: [.caseInsensitive])
            let rev = try? NSRegularExpression(pattern: "^(.+)\\s*-\\s*([A-Za-z ]{1,20})\\s*([0-9]{1,5})([A-Za-z]{0,4})?$", options: [.caseInsensitive])
            func cap(_ re: NSRegularExpression?, _ s: String) -> ParsedName? {
                guard let re = re else { return nil }
                let r = NSRange(s.startIndex..<s.endIndex, in: s)
                if let m = re.firstMatch(in: s, options: [], range: r) {
                    var p = ParsedName()
                    if re == std {
                        p.label = String(s[Range(m.range(at: 1), in: s)!])
                        p.labelNum = String(s[Range(m.range(at: 2), in: s)!])
                        if m.range(at: 3).location != NSNotFound { p.labelExtra = String(s[Range(m.range(at: 3), in: s)!]) }
                        p.title = String(s[Range(m.range(at: 4), in: s)!])
                    } else {
                        p.title = String(s[Range(m.range(at: 1), in: s)!])
                        p.label = String(s[Range(m.range(at: 2), in: s)!])
                        p.labelNum = String(s[Range(m.range(at: 3), in: s)!])
                        if m.range(at: 4).location != NSNotFound { p.labelExtra = String(s[Range(m.range(at: 4), in: s)!]) }
                    }
                    return p
                }
                return nil
            }
            if let p = cap(std, name) { return p }
            if let p = cap(rev, name) { return p }
            return ParsedName(label: "", labelNum: "", labelExtra: "", title: name)
        }
        var mp3Parsed = parseFilename(mp3Name)
        var csParsed = parseFilename(cuesheetName)
        mp3Parsed.label = mp3Parsed.label.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        csParsed.label = csParsed.label.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)

        var score = 0
        var labelMatch = false
        var labelNumberMatch = false
        if !mp3Parsed.label.isEmpty && !csParsed.label.isEmpty {
            if labelWordEqual(mp3Parsed.label, csParsed.label) {
                labelMatch = true
            }
        }
        if !mp3Parsed.labelNum.isEmpty && !csParsed.labelNum.isEmpty {
            let a = Int(mp3Parsed.labelNum) ?? -1
            let b = Int(csParsed.labelNum) ?? -2
            if a == b { labelNumberMatch = true }
        }
        if labelMatch && labelNumberMatch { score += 36 }
        if !mp3Parsed.labelExtra.isEmpty && !csParsed.labelExtra.isEmpty && fuzzyWordEqual(mp3Parsed.labelExtra, csParsed.labelExtra) {
            score += 2
        }

        // Step 7: LCS of title words with fuzzy matching, scaled to 54
        func words(_ s: String) -> [String] { s.split{ $0.isWhitespace }.map(String.init) }
        var mp3TitleWords = filterShortWords(words(mp3Parsed.title))
        var csTitleWords = filterShortWords(words(csParsed.title))
        if mp3TitleWords.isEmpty { mp3TitleWords = words(mp3Parsed.title) }
        if csTitleWords.isEmpty { csTitleWords = words(csParsed.title) }
        let n = mp3TitleWords.count, m = csTitleWords.count
        if n > 0 && m > 0 {
            var lcs = Array(repeating: Array(repeating: 0, count: m+1), count: n+1)
            var maxLen = 0
            if n > 0 && m > 0 {
                for i in 1...n {
                    for j in 1...m {
                        if fuzzyWordEqual(mp3TitleWords[i-1], csTitleWords[j-1]) {
                            lcs[i][j] = lcs[i-1][j-1] + 1
                            if lcs[i][j] > maxLen { maxLen = lcs[i][j] }
                        } else {
                            lcs[i][j] = 0
                        }
                    }
                }
            }
            let maxWordCount = max(n, m)
            if maxWordCount > 0 {
                let pct = (maxLen * 100) / maxWordCount
                let titleMatchScore = min(54, pct * 54 / 100)
                score += titleMatchScore
            }
        }

        score = min(89, score)
        if score <= 35 { return 0 }
        return score
    }
}
