//
//  FigmaLayoutScaler.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 25.02.2026.
//

import SwiftUI

/// Scales sizes from Figma to the current device using a reference canvas.
/// Uses width-based scaling by default for visual consistency.
/// Notes:
/// - If you need height-based scaling for particular elements, use `scaleHeight(_:)`.
/// - Text respects Dynamic Type using UIFontMetrics (optional parameter).
public enum FigmaLayoutScaler {
    /// Reference Figma canvas (change if your design uses another size).
    public static let figmaScreenWidth: CGFloat = 402
    public static let figmaScreenHeight: CGFloat = 874

    /// Width scale factor (primary driver for layout)
    public static var widthScale: CGFloat {
        UIScreen.main.bounds.width / figmaScreenWidth
    }

    /// Height scale factor (rarely used globally)
    public static var heightScale: CGFloat {
        UIScreen.main.bounds.height / figmaScreenHeight
    }

    /// Scale a width value from Figma to device.
    @inlinable
    public static func scaleWidth(_ figmaWidth: CGFloat) -> CGFloat {
        figmaWidth * widthScale
    }

    /// Scale a height value from Figma to device.
    @inlinable
    public static func scaleHeight(_ figmaHeight: CGFloat) -> CGFloat {
        figmaHeight * heightScale
    }

    /// Scale a CGSize from Figma to device.
    @inlinable
    public static func scaleSize(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: scaleWidth(width), height: scaleHeight(height))
    }

    /// Returns a system font scaled from a Figma point size.
    /// - Parameter respectsDynamicType: if true, the font is wrapped with UIFontMetrics for accessibility.
    public static func scaledSystemFont(size: CGFloat,
                                        weight: Font.Weight = .regular,
                                        respectsDynamicType: Bool = true,
                                        relativeTo textStyle: UIFont.TextStyle = .body) -> Font {
        let base = size * widthScale
        if respectsDynamicType {
            // Bridge to UIFontMetrics for proper Dynamic Type scaling
            let uiFont = UIFont.systemFont(ofSize: base, weight: UIFont.Weight(weight))
            let metrics = UIFontMetrics(forTextStyle: textStyle)
            let scaled = metrics.scaledFont(for: uiFont)
            return Font(scaled)
        } else {
            return .system(size: base, weight: weight)
        }
    }

    /// Returns a custom font scaled from a Figma point size.
    /// - Parameter respectsDynamicType: same as above.
    public static func scaledCustomFont(name: String,
                                        size: CGFloat,
                                        respectsDynamicType: Bool = true,
                                        relativeTo textStyle: UIFont.TextStyle = .body) -> Font {
        let base = size * widthScale
        if respectsDynamicType {
            guard let uiFont = UIFont(name: name, size: base) else {
                return .custom(name, size: base)
            }
            let metrics = UIFontMetrics(forTextStyle: textStyle)
            let scaled = metrics.scaledFont(for: uiFont)
            return Font(scaled)
        } else {
            return .custom(name, size: base)
        }
    }
}

// Small adapter to map SwiftUI Font.Weight to UIFont.Weight
private extension UIFont.Weight {
    init(_ weight: Font.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin:       self = .thin
        case .light:      self = .light
        case .regular:    self = .regular
        case .medium:     self = .medium
        case .semibold:   self = .semibold
        case .bold:       self = .bold
        case .heavy:      self = .heavy
        case .black:      self = .black
        default:          self = .regular
        }
    }
}
