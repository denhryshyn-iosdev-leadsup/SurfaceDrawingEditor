//
//  UIImage.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit

// MARK: - UIImage helper

extension UIImage {
    func resizedTo(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: .init()).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Нормализует ориентацию изображения (убирает EXIF rotation)
    func normalizedImage() -> UIImage {
        // Если уже .up - ничего не делаем
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return normalized
    }
}
