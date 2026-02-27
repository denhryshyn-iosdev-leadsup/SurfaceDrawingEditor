//
//  SurfaceType.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit

public enum SurfaceType: String, CaseIterable {
    case wall, floor, ceiling, facade, door, window

    var ade20kIndices: [Int] {
        switch self {
        case .wall:    return [0]
        case .floor:   return [3]
        case .ceiling: return [5]
        case .door:    return [14]
        case .window:  return [8]
        case .facade:  return [1, 25, 49]
        }
    }

    var displayName: String {
        switch self {
        case .wall:    return "Wall"
        case .floor:   return "Floor"
        case .ceiling: return "Ceiling"
        case .door:    return "Door"
        case .window:  return "Window"
        case .facade:  return "Facade"
        }
    }

    var color: UIColor {
        switch self {
        case .wall:    return UIColor(red: 0.27, green: 0.52, blue: 0.95, alpha: 1.0)
        case .floor:   return UIColor(red: 0.95, green: 0.60, blue: 0.20, alpha: 1.0)
        case .ceiling: return UIColor(red: 0.45, green: 0.85, blue: 0.65, alpha: 1.0)
        case .door:    return UIColor(red: 0.85, green: 0.35, blue: 0.35, alpha: 1.0)
        case .window:  return UIColor(red: 0.55, green: 0.35, blue: 0.90, alpha: 1.0)
        case .facade:  return UIColor(red: 0.60, green: 0.40, blue: 0.80, alpha: 1.0)
        }
    }

    var icon: String {
        switch self {
        case .wall:    return "square.fill"
        case .floor:   return "square.bottomhalf.filled"
        case .ceiling: return "square.tophalf.filled"
        case .door:    return "door.left.hand.open"
        case .window:  return "window.vertical.open"
        case .facade:  return "building.2.fill"
        }
    }
}
