//
//  Typography.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 25.02.2026.
//

import SwiftUI

public enum AppFontWeight {
    case regular, medium, semibold, bold, black, light, thin, extraBold, extraLight
}

public extension View {
    /// Uniform way to apply Satoshi with Figma scaling.
    func appFont(_ weight: AppFontWeight, _ size: CGFloat,
                 dynamic: Bool = true,
                 relativeTo style: UIFont.TextStyle = .body) -> some View {
        modifier(AppFontModifier(weight: weight, size: size, dynamic: dynamic, style: style))
    }
}

private struct AppFontModifier: ViewModifier {
    let weight: AppFontWeight
    let size: CGFloat
    let dynamic: Bool
    let style: UIFont.TextStyle

    func body(content: Content) -> some View {
        let name: String = {
            switch weight {
            case .regular:  return "Inter-Regular"
            case .medium:   return "Inter-Medium"
            case .semibold: return "Inter-SemiBold"
            case .bold:     return "Inter-Bold"
            case .black:    return "Inter-Black"
            case .light:    return "Inter-Light"
            case .thin:     return "Inter-Thin"
            case .extraBold:  return "Inter-ExtraBold"
            case .extraLight: return "Inter-ExtraLight"
            }
        }()
        return content.font(
            FigmaLayoutScaler.scaledCustomFont(name: name,
                                               size: size,
                                               respectsDynamicType: dynamic,
                                               relativeTo: style)
        )
    }
}
