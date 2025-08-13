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
//  CircularKnob.swift
//  iSquareDesk
//
//  Created by Assistant on 8/8/25.
//

import SwiftUI

struct CircularKnob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let veinColor: Color
    @State private var lastAngle: Double = 0
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, label: String, veinColor: Color = Color(red: 0/255, green: 156/255, blue: 255/255)) {
        self._value = value
        self.range = range
        self.label = label
        self.veinColor = veinColor
    }
    
    private var angle: Double {
        // Zero is at the center of the range
        let center = (range.upperBound + range.lowerBound) / 2
        let normalizedValue = (value - center) / ((range.upperBound - range.lowerBound) / 2)
        return normalizedValue * 135 // -135 to 135 degrees from vertical
    }
    
    private var arcTrimFrom: CGFloat {
        // When angle is negative (left of center), arc goes from angle position to 0
        // When angle is positive (right of center), arc goes from 0 to angle position
        if angle < 0 {
            // Convert negative angle to position on circle (0 to 1)
            // -135 degrees maps to 0.625 (225/360)
            return CGFloat((angle + 360) / 360.0)
        } else {
            // Arc starts from top (0 position)
            return 0
        }
    }
    
    private var arcTrimTo: CGFloat {
        if angle < 0 {
            // Arc goes to top (0 position) which is 1.0 or 0
            return 1.0
        } else {
            // Convert positive angle to position on circle (0 to 1)
            // 135 degrees maps to 0.375 (135/360)
            return CGFloat(angle / 360.0)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Label to the left of the knob
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .frame(width: 15, alignment: .center)
            
            // Knob
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                // Colored vein from 0 to current position
                Circle()
                    .trim(from: min(arcTrimFrom, arcTrimTo), to: max(arcTrimFrom, arcTrimTo))
                    .stroke(veinColor, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90)) // Rotate so 0 is at top
                
                // Knob indicator - line from center to edge
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 20)
                    .offset(y: -10)
                    .rotationEffect(.degrees(angle))
                
                // Center dot
                Circle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 4)
            }
            .onTapGesture(count: 2) {
                // Double-tap resets to zero (center of range)
                value = (range.upperBound + range.lowerBound) / 2
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        // Initialize lastAngle on first drag if needed
                        if lastAngle == 0 && angle != 0 {
                            lastAngle = angle
                        }
                        let center = CGPoint(x: 20, y: 20)
                        let vector = CGPoint(x: gesture.location.x - center.x, y: gesture.location.y - center.y)
                        var newAngle = atan2(vector.x, -vector.y) * 180 / .pi // Angle from vertical
                        
                        // Prevent snapping across bottom
                        // If we're at far left (-135) and trying to go more left, or
                        // if we're at far right (135) and trying to go more right,
                        // check if we're crossing through the bottom
                        if abs(newAngle - lastAngle) > 180 {
                            // Large jump detected - we're trying to cross the bottom
                            // Clamp to the current extreme
                            if lastAngle < 0 {
                                newAngle = -135
                            } else {
                                newAngle = 135
                            }
                        }
                        
                        // Clamp to -135 to 135 range
                        newAngle = max(-135, min(135, newAngle))
                        
                        // Update last angle for next comparison
                        lastAngle = newAngle
                        
                        // Convert angle to value
                        let normalizedValue = newAngle / 135 // -1 to 1
                        let centerValue = (range.upperBound + range.lowerBound) / 2
                        let halfRange = (range.upperBound - range.lowerBound) / 2
                        value = centerValue + normalizedValue * halfRange
                    }
            )
        }
        .frame(height: 40)
        .onAppear {
            lastAngle = angle
        }
    }
}
