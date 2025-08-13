import Foundation

struct PlaylistItem: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let title: String
    let relativePath: String // relative to music root, e.g., "patter/SSR 320 - Bali Hai.mp3"
}

struct PlaylistData {
    var name: String
    var items: [PlaylistItem]
}

enum PlaylistParseError: Error {
    case fileNotFound
    case invalidEncoding
    case empty
}

/// Very light CSV parser that honors double quotes for commas in fields
private func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var currentRow: [String] = []
    var current = ""
    var inQuotes = false
    var i = text.startIndex
    while i < text.endIndex {
        let ch = text[i]
        if ch == "\"" {
            inQuotes.toggle()
            // peek for escaped quote
            let next = text.index(after: i)
            if inQuotes == false, next < text.endIndex, text[next] == "\"" {
                current.append("\"")
                i = next
            }
        } else if ch == "," && !inQuotes {
            currentRow.append(current)
            current = ""
        } else if (ch == "\n" || ch == "\r") && !inQuotes {
            // commit row on newline
            // support \r\n by skipping following \n
            currentRow.append(current)
            rows.append(currentRow)
            currentRow = []
            current = ""
            // skip \n if next
            let next = text.index(after: i)
            if ch == "\r", next < text.endIndex, text[next] == "\n" {
                i = next
            }
        } else {
            current.append(ch)
        }
        i = text.index(after: i)
    }
    if !current.isEmpty || !currentRow.isEmpty {
        currentRow.append(current)
        rows.append(currentRow)
    }
    return rows
}

struct PlaylistLoader {
    static func loadCSV(url: URL, musicRoot: URL) throws -> PlaylistData {
        print("PlaylistLoader: Loading CSV at \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else { throw PlaylistParseError.fileNotFound }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw PlaylistParseError.invalidEncoding }
        let rows = parseCSV(text)
        guard rows.count >= 1 else { throw PlaylistParseError.empty }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        print("PlaylistLoader: Header columns = \(header)")

        // Robust detection of path column: normalize headers (lowercased, alphanumerics only)
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let normalizedHeader = header.map(norm)
        let pathKeys: Set<String> = [
            "filename", "file", "filepath", "path", "songpath",
            "relativepath", "relpath", "relativefile", "relative",
            "abspath", "absolutepath", "absolute"
        ]
        var pathIdx: Int? = nil
        for (i, col) in normalizedHeader.enumerated() {
            if pathKeys.contains(col) { pathIdx = i; break }
        }
        if let pIdx = pathIdx { print("PlaylistLoader: Detected path column index = \(pIdx) (\(header[pIdx]))") }
        else { print("PlaylistLoader: WARNING - No path column detected; items will be empty") }
        // Ignore other columns for now; title will be derived from the path

        var items: [PlaylistItem] = []
        var rowIndex = 1
        var samplePrinted = 0
        for r in rows.dropFirst() {
            if r.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            var rel: String = ""
            var title: String = ""
            if let pIdx = pathIdx, pIdx < r.count {
                var rawPath = r[pIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                // If provided as file URL, convert to path
                if rawPath.lowercased().hasPrefix("file://") {
                    if let url = URL(string: rawPath), url.isFileURL {
                        rawPath = url.path
                    }
                }
                // Treat value as a path relative to the music root; if it starts with '/', drop exactly one leading slash
                if rawPath.hasPrefix("/") { rawPath.removeFirst() }
                rel = rawPath
            }
            // Derive title from the relative path: drop directories and extension
            let base = URL(fileURLWithPath: rel).deletingPathExtension().lastPathComponent
            if let range = base.range(of: " - ") {
                // Common pattern: "LABEL 123 - Title" -> keep just Title
                title = String(base[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                title = base
            }
            if !rel.isEmpty {
                items.append(PlaylistItem(index: items.count + 1, title: title, relativePath: rel))
                if samplePrinted < 5 { print("PlaylistLoader: + item \(items.count): title='\(title)', rel='\(rel)'"); samplePrinted += 1 }
            }
            rowIndex += 1
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        print("PlaylistLoader: Parsed \(items.count) items from CSV")
        return PlaylistData(name: baseName.isEmpty ? "Untitled Playlist" : baseName, items: items)
    }
}
