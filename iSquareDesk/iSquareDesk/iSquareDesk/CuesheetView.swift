//
//  CuesheetView.swift
//  iSquareDesk
//
//  Created by Assistant on 8/11/25.
//

import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

struct CuesheetView: View {
    @State private var files: [String] = []
    @State private var selectedFile: String = ""
    @State private var htmlContent: String = "<html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"></head><body style=\"font-family: -apple-system, Helvetica; font-size: 18px; color: #111;\"><p>Select a cuesheet from the menu above.</p></body></html>"

    var body: some View {
        VStack(spacing: 8) {
            // Dropdown menu for file selection
            HStack {
                Text("Cuesheet: ")
                    .font(.headline)
                Picker("Cuesheet", selection: $selectedFile) {
                    ForEach(files.isEmpty ? ["(no files)"] : files, id: \.self) { f in
                        Text(f).tag(f)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(.horizontal, 10)

            // Rich text HTML view
            HTMLView(html: htmlContent)
                .background(Color.white)
                .cornerRadius(6)
                .padding(.horizontal, 10)
        }
    }
}

