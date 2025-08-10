import Foundation
import GRDB

struct SongDatabaseRecord: Codable, FetchableRecord {
    var filename: String
    var pitch: Int?
    var tempo: Int?
    var loop: Int?
    var introPos: Float?
    var outroPos: Float?
}

class SongDatabaseManager {
    private var dbQueue: DatabaseQueue?
    private let musicFolderPath: String
    private var songCache: [String: (pitch: Int, tempo: Int, loop: Bool, introPos: Float, outroPos: Float)] = [:]
    private var isCacheLoaded = false
    
    init(musicFolderPath: String) {
        self.musicFolderPath = musicFolderPath
        connectToDatabase()
        loadCache()
    }
    
    private func connectToDatabase() {
        let dbPath = "\(musicFolderPath)/.squaredesk/SquareDesk.sqlite3"
        
        do {
            // Open database in read-only mode for safety
            var config = Configuration()
            config.readonly = true
            dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
// Connected to database
        } catch {
            print("❌ Failed to connect to database: \(error)")
            dbQueue = nil
        }
    }
    
    /// Load entire songs table into memory cache for fast lookups
    private func loadCache() {
        guard let dbQueue = dbQueue else {
            return
        }
        
        do {
            try dbQueue.read { db in
                // Load all songs in one query
                let sql = "SELECT filename, pitch, tempo, loop, introPos, outroPos FROM songs"
                let rows = try Row.fetchAll(db, sql: sql)
                
                // Build cache dictionary
                for row in rows {
                    let filename: String = row["filename"] ?? ""
                    let pitch: Int? = row["pitch"]
                    let tempo: Int? = row["tempo"]
                    let loop: Int? = row["loop"]
                    let introPos: Float? = row["introPos"]
                    let outroPos: Float? = row["outroPos"]
                    
                    if !filename.isEmpty {
                        songCache[filename] = (
                            pitch: pitch ?? 0, 
                            tempo: tempo ?? 125,
                            loop: (loop ?? 0) == 1,
                            introPos: introPos ?? 0.0,
                            outroPos: outroPos ?? 1.0
                        )
                    }
                }
                
                isCacheLoaded = true
            }
        } catch {
            print("❌ Failed to load cache: \(error)")
            isCacheLoaded = false
        }
    }
    
    /// Fetches pitch and tempo for a given relative file path (FAST - uses cache)
    /// - Parameter relativePath: Path relative to music folder (e.g., "patter/SSR 320b - Bali Hai.mp3")
    /// - Returns: Tuple of (pitch, tempo) or nil if not found
    func getPitchAndTempo(for relativePath: String) -> (pitch: Int, tempo: Int)? {
        // Database stores paths with leading slash: /patter/filename.ext
        let dbFilename = "/\(relativePath)"
        
        // Exact cache lookup
        if let cached = songCache[dbFilename] {
            return (pitch: cached.pitch, tempo: cached.tempo)
        }
        
        return nil
    }
    
    /// Fetches pitch, tempo, and loop data for a given relative file path (FAST - uses cache)
    /// - Parameter relativePath: Path relative to music folder (e.g., "patter/SSR 320b - Bali Hai.mp3")
    /// - Returns: Tuple of (pitch, tempo, loop, introPos, outroPos) or nil if not found
    func getPitchTempoAndLoop(for relativePath: String) -> (pitch: Int, tempo: Int, loop: Bool, introPos: Float, outroPos: Float)? {
        // Database stores paths with leading slash: /patter/filename.ext
        let dbFilename = "/\(relativePath)"
        
        // Exact cache lookup
        if let cached = songCache[dbFilename] {
            return cached
        }
        
        return nil
    }
    
    /// Instantly get pitch and tempo using the preloaded cache
    /// - Parameter relativePath: Path relative to music folder
    /// - Returns: Tuple of (pitch, tempo) with defaults if not found
    func getPitchAndTempoWithDefaults(for relativePath: String) -> (pitch: Int, tempo: Int) {
        return getPitchAndTempo(for: relativePath) ?? (pitch: 0, tempo: 125)
    }
    
    /// Batch fetch pitch and tempo for multiple songs (FAST - uses cache)
    /// - Parameter relativePaths: Array of relative paths
    /// - Returns: Dictionary mapping relative path to (pitch, tempo) tuples
    func getBatchPitchAndTempo(for relativePaths: [String]) -> [String: (pitch: Int, tempo: Int)] {
        var results: [String: (pitch: Int, tempo: Int)] = [:]
        
        for path in relativePaths {
            if let values = getPitchAndTempo(for: path) {
                results[path] = values
            }
        }
        
        return results
    }
    
    /// Reload cache (useful if database was updated)
    func reloadCache() {
        songCache.removeAll()
        isCacheLoaded = false
        loadCache()
    }
    
    /// Get cache statistics
    func getCacheStats() -> (loaded: Bool, count: Int) {
        return (loaded: isCacheLoaded, count: songCache.count)
    }
    
}