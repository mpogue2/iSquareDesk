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
    @AppStorage("forceMono") private var forceMono = false
    @AppStorage("switchToCuesheetOnFirstPlay") private var switchToCuesheetOnFirstPlay = false
    @AppStorage("autoScrollCuesheet") private var autoScrollCuesheet = false
    @AppStorage("cuesheetZoomPercent") private var cuesheetZoomPercent: Double = 100.0
    @State private var cuesheetZoomText: String = ""
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
                            Label("Select Folder", systemImage: "folder.fill")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.borderedProminent)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Toggle("Force Mono", isOn: $forceMono)
                            .onChange(of: forceMono) { _, _ in
                                NotificationCenter.default.post(name: NSNotification.Name("ForceMonoChanged"), object: nil)
                            }
                        
                        Text("Convert stereo audio to mono for consistent playback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Playback")) {
                    Toggle("Switch to Cuesheet on first play", isOn: $switchToCuesheetOnFirstPlay)
                    Text("If enabled, when a singing call starts playing for the first time after load, automatically show the Cuesheet tab.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Auto-scroll cuesheet", isOn: $autoScrollCuesheet)
                    Text("Scroll the cuesheet based on the song playhead. ‘OPENER’ is used as the intro anchor.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Cuesheet")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Cuesheet Zoom")
                            Spacer()
                            TextField("100", text: $cuesheetZoomText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .onSubmit { commitZoomText() }
                            Stepper("", value: $cuesheetZoomPercent, in: 10...500, step: 5)
                                .labelsHidden()
                                .onChange(of: cuesheetZoomPercent) { _, newVal in
                                    cuesheetZoomText = String(format: "%.0f", newVal)
                                }
                        }
                        Text("Zoom level in percent (e.g., 120 makes text 1.2×). Use the stepper for ±5%.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Developer Tools")) {
                    NavigationLink(destination: DatabaseTestView()) {
                        Label("Database Tests", systemImage: "cylinder.split.1x2")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString())
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
                        // Persist zoom value on exit
                        commitZoomText()
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
        .onAppear {
            // Initialize text from stored value
            cuesheetZoomText = String(format: "%.0f", cuesheetZoomPercent)
        }
    }
    
    // MARK: - Version helper
    private func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (s?, b?) where !s.isEmpty && !b.isEmpty:
            return "\(s) build \(b)"
        case let (s?, _):
            return s
        case let (_, b?):
            return "build \(b)"
        default:
            return "-"
        }
    }
    
    // MARK: - Zoom helpers
    private func commitZoomText() {
        let raw = cuesheetZoomText.trimmingCharacters(in: .whitespaces)
        let cleaned = raw.replacingOccurrences(of: "%", with: "")
        if let val = Double(cleaned) {
            cuesheetZoomPercent = max(10.0, min(500.0, val))
        }
        // Normalize text display
        cuesheetZoomText = String(format: "%.0f", cuesheetZoomPercent)
    }
    
    func selectMusicFolder(url: URL) {
        let fileManager = FileManager.default
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "Unable to access the selected folder."
            showingAlert = true
            return
        }
        
        // Accept any folder (no .squaredesk required). Store bookmark for persistent access
        do {
            var options: URL.BookmarkCreationOptions = []
            #if targetEnvironment(macCatalyst)
            options.insert(.withSecurityScope)
            options.insert(.securityScopeAllowOnlyReadAccess)
            #endif
            let bookmarkData = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            musicFolderURL = bookmarkData.base64EncodedString()
        } catch {
            print("Failed to create bookmark: \(error)")
        }
        
        musicFolderPath = url.path
        alertMessage = "Music folder updated successfully! The song list will refresh."
        showingAlert = true
        
        // Post notification to refresh song list
        NotificationCenter.default.post(name: NSNotification.Name("RefreshSongList"), object: nil)
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
