//
//  DetectedSurface.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit

public struct DetectedSurface: Identifiable, Equatable {
    public static func == (lhs: DetectedSurface, rhs: DetectedSurface) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id = UUID()
    public let type: SurfaceType
    public let maskIndices: [Int]
    public let maskWidth: Int
    public let maskHeight: Int
    public let coveragePercent: Float

    public var displayName: String { type.displayName }
    public var color: UIColor { type.color }
    public var icon: String { type.icon }
}
