//
//  BrushSlider.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 23.02.2026.
//

import SwiftUI

struct BrushSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    private let thumbSize  = FigmaLayoutScaler.scaleWidth(20)
    private let innerSize  = FigmaLayoutScaler.scaleWidth(10)
    private let trackHeight = FigmaLayoutScaler.scaleHeight(8)

    var body: some View {
        GeometryReader { geo in
            let width    = geo.size.width
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX   = progress * (width - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(height: trackHeight)

                // Track fill
                Capsule()
                    .fill(Color(hex: "#FFBB00"))
                    .frame(width: max(thumbX, thumbSize / 2), height: trackHeight)

                // Thumb
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(
                            color: Color(hex: "#4D3103").opacity(0.15),
                            radius: FigmaLayoutScaler.scaleWidth(6),
                            x: FigmaLayoutScaler.scaleWidth(-1),
                            y: FigmaLayoutScaler.scaleHeight(2)
                        )

                    Circle()
                        .fill(Color(hex: "#FFBB00"))
                        .frame(width: innerSize, height: innerSize)
                }
                .offset(x: thumbX - thumbSize / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let raw     = drag.location.x / width
                            let clamped = min(max(raw, 0), 1)
                            let newVal  = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                            value = (newVal / 5).rounded() * 5
                        }
                )
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
    }
}
