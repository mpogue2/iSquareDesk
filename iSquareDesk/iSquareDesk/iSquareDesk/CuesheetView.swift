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
    let autoScrollEnabled: Bool
    let scrollFraction: Double // 0..1 (0 at intro anchor, 1 at bottom)
    let introMarkerText: String = "OPENER"
    let forceTopTick: Int // when this increments, scroll to absolute top
    let stickToTop: Bool   // if true, keep view at absolute top
    let zoomPercent: Double

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String = ""
        var webView: WKWebView?
        var anchorsReady: Bool = false
        var pendingFraction: Double? = nil
        var lastSentFraction: Double = -1
        var lastSentAt: TimeInterval = 0
        var lastForceTopTick: Int = 0
        var lastZoom: CGFloat = 1.0

        func navigationFinishedSetup(_ webView: WKWebView) {
            let js = "(function(){try{var el=null;var walker=document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);while(walker.nextNode()){var n=walker.currentNode;try{if(n.innerText && /\\bOPENER\\b/i.test(n.innerText)){el=n;break;}}catch(e){}}var openerY=0;if(el){var r=el.getBoundingClientRect();openerY=r.top + window.scrollY;}var docHeight=Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);var viewport=window.innerHeight;var maxScroll=Math.max(0, docHeight-viewport);window._cuesheet={openerY:openerY,docHeight:docHeight,viewport:viewport,maxScrollTop:maxScroll,introTop:Math.max(0, openerY-30)};return true;}catch(e){return false;}})();"
            webView.evaluateJavaScript(js) { [weak self] _, _ in
                self?.anchorsReady = true
                if let f = self?.pendingFraction {
                    self?.setScrollFraction(f, on: webView)
                    self?.pendingFraction = nil
                }
            }
        }

        func setScrollFraction(_ f: Double, on webView: WKWebView) {
            let clamped = max(0.0, min(1.0, f))
            // Throttle updates for smoothness (couple times a second)
            let now = Date().timeIntervalSince1970
            let deltaFrac = abs(clamped - lastSentFraction)
            if now - lastSentAt < 0.25 && deltaFrac < 0.05 { return }
            let js = "(function(){try{if(!window._cuesheet){return -1;}var cs=window._cuesheet;var introTop=cs.introTop||0;var maxTop=cs.maxScrollTop||0;var target=introTop + (" + String(clamped) + ")*(maxTop-introTop);if(!isFinite(target)){target=0;}window.scrollTo({top:target,behavior:'smooth'});return target;}catch(e){return -2;}})();"
            webView.evaluateJavaScript(js, completionHandler: nil)
            lastSentFraction = clamped
            lastSentAt = now
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            navigationFinishedSetup(webView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        // Map percent so that 120 => bigger, 75 => smaller on observed platforms
        let initialZoom = max(0.1, min(5.0, 100.0 / max(1.0, zoomPercent)))
        webView.pageZoom = CGFloat(initialZoom)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Apply page zoom and, if changed post-load, recompute anchors
        // Keep same mapping at update time
        let targetZoom = CGFloat(max(0.1, min(5.0, 100.0 / max(1.0, zoomPercent))))
        if uiView.pageZoom != targetZoom {
            uiView.pageZoom = targetZoom
            if context.coordinator.anchorsReady {
                context.coordinator.navigationFinishedSetup(uiView)
            }
        }
        // Only reload HTML when it actually changes
        if context.coordinator.lastHTML != html {
            context.coordinator.anchorsReady = false
            context.coordinator.lastHTML = html
            uiView.loadHTMLString(html, baseURL: nil)
        } else {
            // Update scroll if enabled and anchors exist
            if autoScrollEnabled {
                // If we should stick to absolute top (stopped at start), do that and skip interpolation
                if stickToTop {
                    let jsTop = "window.scrollTo({top:0,behavior:'auto'});"
                    uiView.evaluateJavaScript(jsTop, completionHandler: nil)
                    context.coordinator.lastSentFraction = -1
                    return
                }
                // Force scroll to absolute top if requested
                if context.coordinator.lastForceTopTick != forceTopTick {
                    context.coordinator.lastForceTopTick = forceTopTick
                    let jsTop = "window.scrollTo({top:0,behavior:'smooth'});"
                    uiView.evaluateJavaScript(jsTop, completionHandler: nil)
                    // Reset lastSentFraction so future throttling doesn't block
                    context.coordinator.lastSentFraction = -1
                    return
                }
                if context.coordinator.anchorsReady {
                    context.coordinator.setScrollFraction(scrollFraction, on: uiView)
                } else {
                    // Defer until anchors are computed after load
                    context.coordinator.pendingFraction = scrollFraction
                }
            }
        }
    }
}

struct CuesheetView: View {
    let files: [String]
    @Binding var selectedIndex: Int?
    let htmlContent: String
    let playheadNormalized: Double // 0..1 of song duration
    let introPos: Double           // 0..1, anchor at OPENER
    let outroPos: Double           // 0..1, end anchor at bottom
    let autoScrollEnabled: Bool
    let forceTopTick: Int
    let stickToTop: Bool
    let zoomPercent: Double

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
            HTMLView(
                html: htmlContent,
                autoScrollEnabled: autoScrollEnabled,
                scrollFraction: computeScrollFraction(),
                forceTopTick: forceTopTick,
                stickToTop: stickToTop,
                zoomPercent: zoomPercent
            )
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

extension CuesheetView {
    // Map playheadNormalized into 0..1 fraction between intro and outro anchors
    func computeScrollFraction() -> Double {
        let start = introPos
        let end = max(introPos, outroPos)
        guard end > start else { return 0 }
        let t = (playheadNormalized - start) / (end - start)
        return min(1.0, max(0.0, t))
    }
}
