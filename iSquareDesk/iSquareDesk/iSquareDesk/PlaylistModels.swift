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
        guard FileManager.default.fileExists(atPath: url.path) else { throw PlaylistParseError.fileNotFound }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw PlaylistParseError.invalidEncoding }
        let rows = parseCSV(text)
        guard rows.count >= 1 else { throw PlaylistParseError.empty }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }

        // possible columns for path
        let pathKeys = ["filename", "path", "relativePath", "relative", "abspath"]
        var pathIdx: Int? = nil
        for (i, col) in header.enumerated() {
            if pathKeys.contains(col.lowercased()) { pathIdx = i; break }
        }
        // a title column is optional; if absent derive from filename
        let titleIdx = header.firstIndex(where: { ["title", "song", "name"].contains($0.lowercased()) })

        var items: [PlaylistItem] = []
        var rowIndex = 1
        for r in rows.dropFirst() {
            if r.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            var rel: String = ""
            var title: String = ""
            if let pIdx = pathIdx, pIdx < r.count {
                let rawPath = r[pIdx].trimmingCharacters(in: .whitespaces)
                if rawPath.hasPrefix("/") {
                    // absolute -> try make relative to musicRoot
                    let root = musicRoot.path.hasSuffix("/") ? musicRoot.path : musicRoot.path + "/"
                    if rawPath.hasPrefix(root) {
                        rel = String(rawPath.dropFirst(root.count))
                    } else {
                        rel = (URL(fileURLWithPath: rawPath).lastPathComponent)
                    }
                } else {
                    rel = rawPath
                }
            }
            if let tIdx = titleIdx, tIdx < r.count {
                title = r[tIdx].trimmingCharacters(in: .whitespaces)
            }
            if title.isEmpty {
                title = URL(fileURLWithPath: rel).deletingPathExtension().lastPathComponent
            }
            if !rel.isEmpty {
                items.append(PlaylistItem(index: items.count + 1, title: title, relativePath: rel))
            }
            rowIndex += 1
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        return PlaylistData(name: baseName.isEmpty ? "Untitled Playlist" : baseName, items: items)
    }
}

