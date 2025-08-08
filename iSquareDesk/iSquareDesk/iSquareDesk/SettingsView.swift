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
                        
                        Button(action: selectMusicFolder) {
                            Label("Select Folder", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)
                        
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
}

#Preview {
    SettingsView()
}