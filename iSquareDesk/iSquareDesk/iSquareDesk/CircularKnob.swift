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
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, label: String) {
        self._value = value
        self.range = range
        self.label = label
    }
    
    private var angle: Double {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return (normalizedValue * 270) - 135 // -135 to 135 degrees (270 degree range)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Label on the left
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .frame(width: 20, alignment: .center)
            
            // Knob in the center
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                // Active arc
                Circle()
                    .trim(from: 0, to: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    .stroke(Color.gray, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                // Knob indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                    .offset(y: -16)
                    .rotationEffect(.degrees(angle))
                
                // Center dot
                Circle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 4)
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let center = CGPoint(x: 20, y: 20)
                        let vector = CGPoint(x: gesture.location.x - center.x, y: gesture.location.y - center.y)
                        let angle = atan2(vector.y, vector.x) * 180 / .pi
                        
                        // Convert angle to 0-270 range (with -135 to 135 mapping)
                        var normalizedAngle = angle + 135
                        if normalizedAngle < 0 {
                            normalizedAngle += 360
                        }
                        
                        // Clamp to 0-270 range
                        normalizedAngle = max(0, min(270, normalizedAngle))
                        
                        // Convert to value
                        let normalizedValue = normalizedAngle / 270
                        value = range.lowerBound + normalizedValue * (range.upperBound - range.lowerBound)
                    }
            )
            
            // Value on the right
            Text("\(Int(value))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .center)
        }
        .frame(height: 40)
    }
}