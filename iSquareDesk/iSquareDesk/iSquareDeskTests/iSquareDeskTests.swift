//
//  iSquareDeskTests.swift
//  iSquareDeskTests
//
//  Created by Mike Pogue on 8/7/25.
//

import Foundation
import Testing
@testable import iSquareDesk

struct iSquareDeskTests {

    // Helper: create a temporary music root with minimal structure
    func makeTempMusicRoot() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("iSquareDeskTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("lyrics"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("singing"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("patter"), withIntermediateDirectories: true)
        return tmp
    }

    @Test func singingMatchesLyrics() async throws {
        let root = try makeTempMusicRoot()

        // Create a couple of cuesheets
        let cs1 = root.appendingPathComponent("lyrics/RR 103 - Rocky Top.html")
        let cs2 = root.appendingPathComponent("lyrics/ZZ 999 - Another Song.html")
        try "<html>Rocky Top</html>".write(to: cs1, atomically: true, encoding: .utf8)
        try "<html>Another</html>".write(to: cs2, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        // MP3 filename that should match cs1 via title LCS
        let songURL = root.appendingPathComponent("singing/RR 103B - Rocky Top.mp3")
        let matches = matcher.betterFindPossibleCuesheets(songFile: songURL)

        #expect(matches.count >= 1)
        #expect(matches.contains { $0.url.lastPathComponent == cs1.lastPathComponent })

        // Highest score should be the Rocky Top cuesheet
        #expect(matches.first?.url.lastPathComponent == cs1.lastPathComponent)
        // Display name should be relative path
        #expect(matches.first?.displayName.hasPrefix("lyrics/") == true)
    }

    @Test func patterSkipsLyrics() async throws {
        let root = try makeTempMusicRoot()

        // Create a lyrics cuesheet
        let cs1 = root.appendingPathComponent("lyrics/RIV 307 - Going to Ceili.html")
        try "<html>Ceili</html>".write(to: cs1, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        // Patter song should not match lyrics folder
        let patterSong = root.appendingPathComponent("patter/RIV 307 - Going to Ceili.mp3")
        let matches = matcher.betterFindPossibleCuesheets(songFile: patterSong)
        #expect(matches.isEmpty)
    }

    @Test func loadCuesheetsPreselectsLast() async throws {
        let root = try makeTempMusicRoot()

        // Create two cuesheets
        let preferred = root.appendingPathComponent("lyrics/RR 147 - Amarillo By Morning.html")
        let other = root.appendingPathComponent("lyrics/RR 147 - Amarillo By Morning (Alt).html")
        try "<html>Preferred</html>".write(to: preferred, atomically: true, encoding: .utf8)
        try "<html>Other</html>".write(to: other, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        // Simulate DB having last_cuesheet with a different root
        let lastFromOldRoot = "/Some/Old/Path/lyrics/\(preferred.lastPathComponent)"

        let songURL = root.appendingPathComponent("singing/RR 147 - Amarillo By Morning.mp3")
        let res = matcher.loadCuesheets(songFile: songURL, songType: "singing", lastCuesheetAbsolutePath: lastFromOldRoot)

        #expect(res.items.count == 2)
        #expect(res.selectedIndex != nil)
        if let idx = res.selectedIndex {
            #expect(res.items[idx].hasSuffix(preferred.lastPathComponent))
        }
    }

    @Test func nbNormalizationMatches() async throws {
        let root = try makeTempMusicRoot()

        // Cuesheet uses space, MP3 uses dash in NB-303
        let cs = root.appendingPathComponent("lyrics/Only You - NB 303.html")
        try "<html>Only You</html>".write(to: cs, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        let songURL = root.appendingPathComponent("singing/Only You - NB-303.mp3")
        let matches = matcher.betterFindPossibleCuesheets(songFile: songURL)

        #expect(matches.first?.url.lastPathComponent == cs.lastPathComponent)
        #expect(matches.first?.score == 100) // exact match after normalization
    }

    @Test func dotNumberRemovalMatches() async throws {
        let root = try makeTempMusicRoot()

        // Cuesheet with trailing .2 should match base name
        let cs = root.appendingPathComponent("lyrics/Blue.2.html")
        try "<html>Blue</html>".write(to: cs, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        let songURL = root.appendingPathComponent("singing/Blue.mp3")
        let matches = matcher.betterFindPossibleCuesheets(songFile: songURL)
        #expect(matches.first?.url.lastPathComponent == cs.lastPathComponent)
        #expect(matches.first?.score == 100) // exact after removing .2
    }

    @Test func labelAliasMatchRRvsRhythmRecords() async throws {
        let root = try makeTempMusicRoot()

        // Place a label alias CSV at parent/Resources so matcher can load it
        let resourcesDir = root.deletingLastPathComponent().appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        let csv = resourcesDir.appendingPathComponent("squareDanceLabelIDs.csv")
        // name, pitch, id  (only name and id used in matcher)
        // Map RR -> Rhythm Records
        try "Rhythm Records,0,RR\n".write(to: csv, atomically: true, encoding: .utf8)

        // Cuesheet with full label name, MP3 with ID
        let cs = root.appendingPathComponent("lyrics/Rhythm Records 147 - Amarillo By Morning.html")
        try "<html>ABM</html>".write(to: cs, atomically: true, encoding: .utf8)

        let matcher = CuesheetMatcher(musicRoot: root)
        matcher.buildPathStackCuesheets()

        let songURL = root.appendingPathComponent("singing/RR 147 - Amarillo By Morning.mp3")
        let matches = matcher.betterFindPossibleCuesheets(songFile: songURL)

        #expect(matches.count >= 1)
        #expect(matches.first?.url.lastPathComponent == cs.lastPathComponent)
        #expect((matches.first?.score ?? 0) > 35)
    }
}
