//
//  AppLaunchView.swift
//  iSquareDesk
//
//  Created by Claude on 8/9/25.
//

import SwiftUI

struct AppLaunchView: View {
    @State private var showingSplash = true
    @State private var splashOpacity = 1.0
    
    var body: some View {
        ZStack {
            // Main content view
            if !showingSplash {
                ContentView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
            
            // Splash screen overlay
            if showingSplash {
                SplashScreenView()
                    .opacity(splashOpacity)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Show splash screen for minimum 2 seconds, then fade out over 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    splashOpacity = 0.0
                }
                
                // Remove splash screen after fade animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSplash = false
                    }
                }
            }
        }
    }
}

#Preview {
    AppLaunchView()
}