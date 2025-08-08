//
//  SettingsView.swift
//  iSquareDesk
//
//  Created by Assistant on 8/7/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("musicFolderPath") private var musicFolderPath = "/Users/mpogue/ipad_squaredesk/SquareDanceMusic"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Music Library")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Music Folder")
                            .font(.headline)
                        
                        Text(musicFolderPath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        HStack {
                            Button(action: selectMusicFolder) {
                                Label("Select Folder", systemImage: "folder")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: createSampleFolder) {
                                Label("Create Sample", systemImage: "plus.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Text("Future versions will support selecting folders from iCloud Drive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Compatible with")
                        Spacer()
                        Text("SquareDesk")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func selectMusicFolder() {
        // For now, the path is hardcoded
        // In future versions, we'll use UIDocumentPickerViewController
        // to allow selecting folders from iCloud Drive
    }
    
    func createSampleFolder() {
        let fileManager = FileManager.default
        let sampleMusicPath = musicFolderPath
        
        do {
            // Create main folder if it doesn't exist
            try fileManager.createDirectory(atPath: sampleMusicPath, withIntermediateDirectories: true, attributes: nil)
            
            // Create sample subfolders with sample files
            let subfolders = ["Country", "Pop", "Rock", "Square Dance"]
            let sampleFiles = [
                "Country": ["Country Song 1.mp3", "Country Song 2.m4a", "Western Swing.mp3"],
                "Pop": ["Pop Hit 1.mp3", "Dance Track.m4a", "Chart Topper.mp3"],
                "Rock": ["Rock Anthem.mp3", "Classic Rock.m4a", "Heavy Metal.mp3"],
                "Square Dance": ["Do Si Do.mp3", "Promenade All.m4a", "Allemande Left.mp3", "Circle Left.mp3"]
            ]
            
            for subfolder in subfolders {
                let subfolderPath = sampleMusicPath + "/" + subfolder
                try fileManager.createDirectory(atPath: subfolderPath, withIntermediateDirectories: true, attributes: nil)
                
                // Create empty sample files
                if let files = sampleFiles[subfolder] {
                    for fileName in files {
                        let filePath = subfolderPath + "/" + fileName
                        if !fileManager.fileExists(atPath: filePath) {
                            let sampleData = "Sample audio file content".data(using: .utf8)!
                            fileManager.createFile(atPath: filePath, contents: sampleData, attributes: nil)
                        }
                    }
                }
            }
            
            print("Sample music folder created successfully at: \(sampleMusicPath)")
        } catch {
            print("Error creating sample folder: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}