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
