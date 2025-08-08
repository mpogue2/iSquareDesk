//
//  VerticalSlider.swift
//  iSquareDesk
//
//  Created by Assistant on 8/7/25.
//

import SwiftUI

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let showMax: Bool
    let defaultValue: Double
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, label: String, showMax: Bool = false, defaultValue: Double? = nil) {
        self._value = value
        self.range = range
        self.label = label
        self.showMax = showMax
        self.defaultValue = defaultValue ?? range.lowerBound
    }
    
    var displayValue: String {
        if label == "Volume" {
            if value >= 1.0 {
                return "MAX"
            }
            return "\(Int(value * 100))"
        }
        return "\(Int(value))"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .frame(width: 50)
                .multilineTextAlignment(.center)
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 6)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray)
                        .frame(width: 6, height: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height)
                    
                    // Thumb (positioned with 10px margin from top and bottom)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        .position(
                            x: geometry.size.width / 2, // Center horizontally on the track
                            y: 10 + CGFloat((1 - (value - range.lowerBound) / (range.upperBound - range.lowerBound))) * (geometry.size.height - 20)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let trackHeight = geometry.size.height - 20
                                    let clampedY = max(10, min(gesture.location.y, geometry.size.height - 10))
                                    let normalizedPosition = (clampedY - 10) / trackHeight
                                    let newValue = range.upperBound - (normalizedPosition * (range.upperBound - range.lowerBound))
                                    value = min(max(newValue, range.lowerBound), range.upperBound)
                                }
                        )
                        .onTapGesture(count: 2) {
                            value = defaultValue
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 50, height: 130)
            
            Text(displayValue)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .frame(width: 50)
                .multilineTextAlignment(.center)
        }
        .frame(width: 50)
    }
}