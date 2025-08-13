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
    let files: [String]
    @Binding var selectedIndex: Int?
    let htmlContent: String

    private var selectionBinding: Binding<Int> {
        Binding<Int>(
            get: { selectedIndex ?? 0 },
            set: { newVal in
                if files.indices.contains(newVal) {
                    selectedIndex = newVal
                } else {
                    selectedIndex = nil
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            // Dropdown menu for file selection
            HStack {
                Text("Cuesheet: ")
                    .font(.headline)
                if files.isEmpty {
                    Picker("Cuesheet", selection: .constant(0)) {
                        Text("(no files)").tag(0)
                    }
                    .pickerStyle(.menu)
                    .disabled(true)
                } else {
                    Picker("Cuesheet", selection: selectionBinding) {
                        ForEach(Array(files.enumerated()), id: \.offset) { idx, f in
                            Text(f).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Spacer()
            }
            .padding(.horizontal, 10)

            // Rich text HTML view
            HTMLView(html: htmlContent)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 10)
        }
    }
}
