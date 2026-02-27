//
//  DrawingStroke.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit

// MARK: - Drawing Stroke

public struct DrawingStroke: Identifiable, Equatable {
    public let id = UUID()
    public let points:     [CGPoint]
    public let tool:       DrawingTool
    public let brushWidth: CGFloat
    public let color:      UIColor

    public static func == (lhs: DrawingStroke, rhs: DrawingStroke) -> Bool { lhs.id == rhs.id }
}
