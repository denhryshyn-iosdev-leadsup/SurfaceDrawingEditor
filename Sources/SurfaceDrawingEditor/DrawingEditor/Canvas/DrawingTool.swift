//
//  DrawingTool.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import Foundation

// MARK: - Drawing Tool

public enum DrawingTool {
    case brush
    case eraser

    var activeIcon: String {
        switch self {
        case .brush:  return "paint_active_ic"
        case .eraser: return "eraser_active_ic"
        }
    }
    
    var inactiveIcon: String {
        switch self {
        case .brush:  return "paint_inactive_ic"
        case .eraser: return "eraser_inactive_ic"
        }
    }
}
