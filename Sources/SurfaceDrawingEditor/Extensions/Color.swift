//
//  Color.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 25.02.2026.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let r, g, b, a: Double
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        
        func component(_ start: Int) -> Double {
            let s = hexString.index(hexString.startIndex, offsetBy: start)
            let e = hexString.index(s, offsetBy: 2)
            let str = String(hexString[s..<e])
            return Double(Int(str, radix: 16) ?? 0) / 255.0
        }
        
        switch hexString.count {
        case 6:
            r = component(0); g = component(2); b = component(4); a = 1.0
        case 8:
            r = component(0); g = component(2); b = component(4); a = component(6)
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
