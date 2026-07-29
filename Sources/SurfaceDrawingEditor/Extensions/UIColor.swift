//
//  File.swift
//  SurfaceDrawingEditor
//
//  Created by _d3n_o77 on 29.07.2026.
//

import UIKit

extension UIColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        func component(_ start: Int) -> CGFloat {
            let s = hexString.index(hexString.startIndex, offsetBy: start)
            let e = hexString.index(s, offsetBy: 2)
            let str = String(hexString[s..<e])
            return CGFloat(Int(str, radix: 16) ?? 0) / 255.0
        }

        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6:
            r = component(0); g = component(2); b = component(4); a = 1.0
        case 8:
            r = component(0); g = component(2); b = component(4); a = component(6)
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
