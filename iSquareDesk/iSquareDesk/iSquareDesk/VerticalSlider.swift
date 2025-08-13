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
    let isTempoPercent: Bool
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, label: String, showMax: Bool = false, defaultValue: Double? = nil, allowTapIncrement: Bool = false, incrementAmount: Double = 1.0, snapToIntegers: Bool = false, vuLevel: Double? = nil, isTempoPercent: Bool = false) {
        self._value = value
        self.range = range
        self.label = label
        self.showMax = showMax
        self.defaultValue = defaultValue ?? range.lowerBound
        self.allowTapIncrement = allowTapIncrement
        self.incrementAmount = incrementAmount
        self.snapToIntegers = snapToIntegers
        self.vuLevel = vuLevel
        self.isTempoPercent = isTempoPercent
    }
    
    var displayValue: String {
        if label == "Volume" {
            if value >= 1.0 {
                return "MAX"
            }
            return "\(Int(value * 100))"
        }
        if label == "Tempo" && isTempoPercent {
            return "\(Int(value))%"
        }
        if label == "Pitch" {
            let intValue = Int(value)
            if intValue > 0 {
                return "+\(intValue)"
            }
            return "\(intValue)"
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
                    // Track background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 6)
                    
                    // VU Meter or Regular Fill
                    if let vuLevel = vuLevel, label == "Volume" {
                        // Single line VU meter with level-based color
                        let vuHeight = CGFloat(vuLevel) * geometry.size.height
                        let vuColor = getVUColor(level: vuLevel)
                        
                        // VU meter bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(vuColor)
                            .frame(width: 6, height: vuHeight)
                            .animation(.linear(duration: 0.05), value: vuLevel)
                        
                        // Volume level indicator (thin white line)
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 8, height: 1)
                            .position(
                                x: geometry.size.width / 2,
                                y: geometry.size.height - (CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height)
                            )
                    } else {
                        // Regular vein for Pitch/Tempo: base vein is #919191, highlight from center to handle is #009CFF
                        let baseVein = Color(hex: "#DDDDDF")
                        let activeVein = Color(hex: "#009CFF")

                        // Draw base vein across full height
                        RoundedRectangle(cornerRadius: 2)
                            .fill(baseVein)
                            .frame(width: 6)

                        // Compute handle position and center
                        let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                        let handleY = 10 + (1 - normalized) * (geometry.size.height - 20)
                        let centerY = geometry.size.height / 2
                        let highlightHeight = abs(centerY - handleY)
                        let highlightMidY = min(centerY, handleY) + (highlightHeight / 2)

                        // Draw active segment from center to handle position
                        Rectangle()
                            .fill(activeVein)
                            .frame(width: 6, height: max(0, highlightHeight))
                            .position(x: geometry.size.width / 2, y: highlightMidY)
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
    
    // Helper function to get VU meter color with smooth interpolation
    private func getVUColor(level: Double) -> Color {
        if level <= 0.8 {
            // 0% to 80%: solid green
            return Color.green
        } else if level <= 0.9 {
            // 80% to 90%: interpolate from green to red
            let progress = (level - 0.8) / 0.1 // 0.0 to 1.0
            return interpolateColor(from: Color.green, to: Color.red, progress: progress)
        } else {
            // 90% to 100%: solid red
            return Color.red
        }
    }
    
    // Helper function to interpolate between two colors
    private func interpolateColor(from startColor: Color, to endColor: Color, progress: Double) -> Color {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        // Convert SwiftUI Colors to RGB components
        let startRGB = UIColor(startColor).getRGBComponents()
        let endRGB = UIColor(endColor).getRGBComponents()
        
        // Interpolate each component
        let red = startRGB.red + (endRGB.red - startRGB.red) * clampedProgress
        let green = startRGB.green + (endRGB.green - startRGB.green) * clampedProgress
        let blue = startRGB.blue + (endRGB.blue - startRGB.blue) * clampedProgress
        
        return Color(red: red, green: green, blue: blue)
    }
}

// Extension to extract RGB components from UIColor
extension UIColor {
    func getRGBComponents() -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red: Double(red), green: Double(green), blue: Double(blue))
    }
}
