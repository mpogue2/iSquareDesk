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
                        let center = CGPoint(x: 20, y: 20)
                        let vector = CGPoint(x: gesture.location.x - center.x, y: gesture.location.y - center.y)
                        var angle = atan2(vector.x, -vector.y) * 180 / .pi // Angle from vertical
                        
                        // Clamp to -135 to 135 range
                        angle = max(-135, min(135, angle))
                        
                        // Convert angle to value
                        let normalizedValue = angle / 135 // -1 to 1
                        let centerValue = (range.upperBound + range.lowerBound) / 2
                        let halfRange = (range.upperBound - range.lowerBound) / 2
                        value = centerValue + normalizedValue * halfRange
                    }
            )
        }
        .frame(height: 40)
    }
}