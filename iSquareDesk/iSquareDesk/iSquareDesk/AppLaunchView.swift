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
