/*****************************************************************************
**
** Copyright (C) 2025 Mike Pogue, Dan Lyke
** Contact: mpogue @ zenstarstudio.com
**
** This file is part of the iSquareDesk application.
**
** $ISQUAREDESK_BEGIN_LICENSE$
**
** Commercial License Usage
** For commercial licensing terms and conditions, contact the authors via the
** email address above.
**
** GNU General Public License Usage
** This file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appear in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file.
**
** $ISQUAREDESK_END_LICENSE$
**
****************************************************************************/
import SwiftUI
import GRDB

struct DatabaseTestView: View {
    @State private var testResults: String = "Tap 'Run Tests' to begin"
    @State private var isRunning: Bool = false
    @State private var databasePath: String = ""
    @State private var showFileImporter: Bool = false
    @AppStorage("musicFolderPath") private var musicFolderPath = ""
    
    private let dbManager = DatabaseManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("GRDB Database Tests")
                .font(.largeTitle)
                .padding()
            
            VStack(spacing: 15) {
                Button(action: runInMemoryTests) {
                    Label("Run In-Memory Tests", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Database path", text: $databasePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        Button("Browse") {
                            showFileImporter = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Tip: You can manually enter the path to .squaredesk folders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: useMusicFolderDatabase) {
                        Label("Use Music Folder Database", systemImage: "music.note.house")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                
                Button(action: testExistingDatabase) {
                    Label("Test Existing Database", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || databasePath.isEmpty)
            }
            .padding(.horizontal)
            
            ScrollView {
                Text(testResults)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if isRunning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
        .onAppear {
            // Automatically set the database path when view appears
            if databasePath.isEmpty && !musicFolderPath.isEmpty {
                useMusicFolderDatabase()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.database, .data, .item],
            onCompletion: handleFileSelection
        )
    }
    
    private func runInMemoryTests() {
        isRunning = true
        testResults = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            var output = ""
            
            let outputHandler = { (text: String) in
                output += text + "\n"
                DispatchQueue.main.async {
                    self.testResults = output
                }
            }
            
            captureOutput(outputHandler) {
                dbManager.runAllTests()
            }
            
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    private func testExistingDatabase() {
        isRunning = true
        testResults = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            var output = ""
            
            let outputHandler = { (text: String) in
                output += text + "\n"
                DispatchQueue.main.async {
                    self.testResults = output
                }
            }
            
            captureOutput(outputHandler) {
                dbManager.testWithExistingDatabase(at: databasePath)
            }
            
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    private func handleFileSelection(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            databasePath = url.path
        case .failure(let error):
            testResults = "Error selecting file: \(error.localizedDescription)"
        }
    }
    
    private func useMusicFolderDatabase() {
        // Use the music folder path from settings
        let dbPath = "\(musicFolderPath)/.squaredesk/SquareDesk.sqlite3"
        
        // Check if the database file exists
        if FileManager.default.fileExists(atPath: dbPath) {
            databasePath = dbPath
            testResults = "Found SquareDesk.sqlite3 database at: \(dbPath)"
        } else {
            // If not found, still set the path but warn the user
            databasePath = dbPath
            testResults = "Database path set to: \(dbPath)\nWarning: File may not exist at this location."
        }
    }
    
    private func captureOutput(_ handler: @escaping (String) -> Void, _ block: () -> Void) {
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                handler(output)
            }
        }
        
        block()
        
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        
        pipe.fileHandleForReading.readabilityHandler = nil
    }
}

#Preview {
    DatabaseTestView()
}
