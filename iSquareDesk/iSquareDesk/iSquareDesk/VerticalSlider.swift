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
    let allowTapIncrement: Bool
    let incrementAmount: Double
    let snapToIntegers: Bool
    let vuLevel: Double? // Optional VU meter level (0.0 to 1.0)
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, label: String, showMax: Bool = false, defaultValue: Double? = nil, allowTapIncrement: Bool = false, incrementAmount: Double = 1.0, snapToIntegers: Bool = false, vuLevel: Double? = nil) {
        self._value = value
        self.range = range
        self.label = label
        self.showMax = showMax
        self.defaultValue = defaultValue ?? range.lowerBound
        self.allowTapIncrement = allowTapIncrement
        self.incrementAmount = incrementAmount
        self.snapToIntegers = snapToIntegers
        self.vuLevel = vuLevel
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
                .onTapGesture {
                    // Tap on label = increment
                    if allowTapIncrement {
                        let newValue = min(value + incrementAmount, range.upperBound)
                        if snapToIntegers {
                            value = round(newValue)
                        } else {
                            value = newValue
                        }
                    }
                }
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 6)
                    
                    // VU Meter or Regular Fill
                    if let vuLevel = vuLevel, label == "Volume" {
                        // VU meter display with gradient
                        let vuHeight = CGFloat(vuLevel) * geometry.size.height
                        
                        // Create gradient based on VU level
                        let gradient = LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .green, location: 0.0),
                                .init(color: .green, location: 0.6),
                                .init(color: .yellow, location: 0.8),
                                .init(color: .orange, location: 0.9),
                                .init(color: .red, location: 1.0)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        
                        // VU meter bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(gradient)
                            .frame(width: 6, height: vuHeight)
                            .animation(.linear(duration: 0.05), value: vuLevel)
                        
                        // Volume level indicator (dimmed)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height)
                            .overlay(
                                // Add a thin line at the actual volume level
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 6, height: 1)
                                    .offset(y: -CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height)
                            )
                    } else {
                        // Regular fill for non-VU mode
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray)
                            .frame(width: 6, height: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height)
                    }
                    
                    // Thumb (positioned with 10px margin from top and bottom)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        .position(
                            x: geometry.size.width / 2, // Center horizontally on the track
                            y: 10 + CGFloat((1 - (value - range.lowerBound) / (range.upperBound - range.lowerBound))) * (geometry.size.height - 20)
                        )
                        .onTapGesture(count: 2) {
                            value = defaultValue
                        }
                }
                .contentShape(Rectangle()) // Make entire area draggable
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            let trackHeight = geometry.size.height - 20
                            let clampedY = max(10, min(gesture.location.y, geometry.size.height - 10))
                            let normalizedPosition = (clampedY - 10) / trackHeight
                            let newValue = range.upperBound - (normalizedPosition * (range.upperBound - range.lowerBound))
                            let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                            
                            // Snap to integers if enabled
                            if snapToIntegers {
                                value = round(clampedValue)
                            } else {
                                value = clampedValue
                            }
                        }
                )
                .frame(maxWidth: .infinity)
            }
            .frame(width: 50, height: 130)
            
            Text(displayValue)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .onTapGesture {
                    // Tap on value = decrement
                    if allowTapIncrement {
                        let newValue = max(value - incrementAmount, range.lowerBound)
                        if snapToIntegers {
                            value = round(newValue)
                        } else {
                            value = newValue
                        }
                    }
                }
        }
        .frame(width: 50)
    }
}