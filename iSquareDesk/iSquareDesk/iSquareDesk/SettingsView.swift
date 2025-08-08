//
//  SettingsView.swift
//  iSquareDesk
//
//  Created by Assistant on 8/7/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("musicFolderPath") private var musicFolderPath = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        return documentsPath + "/SquareDanceMusic"
    }()
    @AppStorage("musicFolderURL") private var musicFolderURL = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showingFolderPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Music Library")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Music Folder")
                            .font(.headline)
                        
                        TextField("Music folder path", text: $musicFolderPath)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                // Post notification to refresh song list when user finishes editing
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshSongList"), object: nil)
                            }
                        
                        Button(action: { showingFolderPicker = true }) {
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
        .sheet(isPresented: $showingFolderPicker) {
            DocumentPicker(onFolderSelected: selectMusicFolder)
        }
        .alert("Folder Selection", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func selectMusicFolder(url: URL) {
        let fileManager = FileManager.default
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "Unable to access the selected folder."
            showingAlert = true
            return
        }
        
        // Check if the folder contains a .squaredesk subfolder
        let squaredeskURL = url.appendingPathComponent(".squaredesk")
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: squaredeskURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            // Store the security-scoped URL data for persistent access
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                musicFolderURL = bookmarkData.base64EncodedString()
            } catch {
                print("Failed to create bookmark: \(error)")
            }
            
            // Update the music folder path to the parent folder that contains .squaredesk
            musicFolderPath = url.path
            alertMessage = "Music folder updated successfully! The song list will refresh."
            showingAlert = true
            
            // Post notification to refresh song list
            NotificationCenter.default.post(name: NSNotification.Name("RefreshSongList"), object: nil)
        } else {
            url.stopAccessingSecurityScopedResource()
            alertMessage = "Selected folder must contain a '.squaredesk' subfolder."
            showingAlert = true
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onFolderSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onFolderSelected(url)
        }
    }
}

#Preview {
    SettingsView()
}