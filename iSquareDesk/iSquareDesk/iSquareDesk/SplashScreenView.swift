//
//  SplashScreenView.swift
//  iSquareDesk
//
//  Created by Claude on 8/9/25.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // Background color - you can customize this
            Color.white
                .ignoresSafeArea()
            
            // Splash screen image
            Image("SplashScreen")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400, maxHeight: 300)
        }
    }
}

#Preview {
    SplashScreenView()
}