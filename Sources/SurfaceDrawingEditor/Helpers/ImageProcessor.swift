//
//  ImageProcessor.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 25.02.2026.
//

import UIKit

public enum ImageProcessingError: Error {
    case invalidImage
    case compressionFailed
}

public struct ImageProcessor {

    // MARK: - Public API

    /// Возвращает сжатый Data (JPEG ≤ maxSizeMB, ≤ maxDimension пикселей)
    static func process(
        imageData: Data,
        maxSizeMB: Double = 10,
        maxDimension: CGFloat = 4096
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try Self._process(imageData: imageData, maxSizeMB: maxSizeMB, maxDimension: maxDimension)
        }.value
    }

    /// Возвращает сжатый UIImage
    static func process(
        image: UIImage,
        maxSizeMB: Double = 10,
        maxDimension: CGFloat = 4096
    ) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            guard let data = image.jpegData(compressionQuality: 0.92) else {
                throw ImageProcessingError.compressionFailed
            }
            let compressed = try Self._process(imageData: data, maxSizeMB: maxSizeMB, maxDimension: maxDimension)
            guard let result = UIImage(data: compressed) else {
                throw ImageProcessingError.invalidImage
            }
            return result
        }.value
    }

    // MARK: - Internal sync core

    private static func _process(
        imageData: Data,
        maxSizeMB: Double,
        maxDimension: CGFloat
    ) throws -> Data {
        let maxBytes = Int(maxSizeMB * 1024 * 1024)
        guard var image = UIImage(data: imageData) else { throw ImageProcessingError.invalidImage }
                
        image = image.normalizedImage()
        image = resizeIfNeeded(image, maxDimension: maxDimension)
                
        guard var data = image.jpegData(compressionQuality: 0.9) else { throw ImageProcessingError.compressionFailed }
                
        if data.count <= maxBytes { return data }

        // Снижаем качество шагами 0.8 → 0.1
        var compression: CGFloat = 0.8
        while data.count > maxBytes && compression > 0.1 {
            guard let compressed = image.jpegData(compressionQuality: compression) else {
                throw ImageProcessingError.compressionFailed
            }
            data = compressed
            compression -= 0.1
        }
        if data.count <= maxBytes { return data }

        // Если всё ещё больше — уменьшаем разрешение
        while data.count > maxBytes {
            image = downscale(image, factor: 0.9)
            guard let resizedData = image.jpegData(compressionQuality: 0.7) else {
                throw ImageProcessingError.compressionFailed
            }
            data = resizedData
        }

        return data
    }

    // MARK: - Helpers

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth  = image.size.width  * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxSide = max(pixelWidth, pixelHeight)
        guard maxSide > maxDimension else { return image }
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func downscale(_ image: UIImage, factor: CGFloat) -> UIImage {
        let pixelWidth  = image.size.width  * image.scale
        let pixelHeight = image.size.height * image.scale
        let newSize = CGSize(width: pixelWidth * factor, height: pixelHeight * factor)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
