//
//  CompositeRenderer.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit
import CoreGraphics

/// Рисует overlay (auto-detect + ручные штрихи) поверх оригинальной картинки
enum CompositeRenderer {

    static func render(
        original: UIImage,
        autoSurface: DetectedSurface?,
        strokes: [DrawingStroke],
        canvasSize: CGSize
    ) -> UIImage {
        // ← пиксельный размер, не логический
        let pixelW = Int(original.size.width * original.scale)
        let pixelH = Int(original.size.height * original.scale)

        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH, bitsPerComponent: 8, bytesPerRow: pixelW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return original }

        let rect = CGRect(x: 0, y: 0, width: pixelW, height: pixelH)

        if let cg = original.normalizedImage().cgImage {
            ctx.draw(cg, in: rect)
        }

        if let overlayCtx = CGContext(
            data: nil, width: pixelW, height: pixelH, bitsPerComponent: 8, bytesPerRow: pixelW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {

            if let surface = autoSurface {
                drawSurfaceMask(surface, in: overlayCtx, W: pixelW, H: pixelH)
            }

            // imageSize тоже пиксельная
            let pixelSize = CGSize(width: pixelW, height: pixelH)
            drawStrokes(strokes, in: overlayCtx, imageSize: pixelSize, canvasSize: canvasSize)

            if let overlayCG = overlayCtx.makeImage() {
                ctx.draw(overlayCG, in: rect)
            }
        }

        guard let finalCG = ctx.makeImage() else { return original }
        return UIImage(cgImage: finalCG, scale: original.scale, orientation: .up)
    }

    // MARK: - Canvas overlay (для preview в ZoomableDrawingContainer)

    static func makeAutoOverlay(surface: DetectedSurface, size: CGSize) -> UIImage? {
        let W = Int(size.width), H = Int(size.height)
        let mw = surface.maskWidth, mh = surface.maskHeight

        var bytes = [UInt8](repeating: 0, count: mw * mh)
        for i in surface.maskIndices { bytes[i] = 255 }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let maskCG = CGImage(
                width: mw, height: mh, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: mw,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let ctx = CGContext(
                data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H), mask: maskCG)
        ctx.setFillColor(UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        guard let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Private helpers

    private static func drawSurfaceMask(_ surface: DetectedSurface, in ctx: CGContext, W: Int, H: Int) {
        let mw = surface.maskWidth, mh = surface.maskHeight
        var bytes = [UInt8](repeating: 0, count: mw * mh)
        for i in surface.maskIndices { bytes[i] = 255 }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let maskCG = CGImage(
                width: mw, height: mh, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: mw,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return }

        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H), mask: maskCG)
        ctx.setFillColor(UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.restoreGState()
    }

    private static func drawStrokes(
        _ strokes: [DrawingStroke],
        in ctx: CGContext,
        imageSize: CGSize,
        canvasSize: CGSize
    ) {
        guard !strokes.isEmpty else { return }
        let scaleX = imageSize.width  / canvasSize.width
        let scaleY = imageSize.height / canvasSize.height

        ctx.saveGState()
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: 0, y: canvasSize.height)
        ctx.scaleBy(x: 1, y: -1)

        for stroke in strokes {
            guard stroke.points.count > 1 else { continue }
            if stroke.tool == .eraser {
                ctx.setBlendMode(.clear)
                ctx.setStrokeColor(UIColor.white.cgColor)
            } else {
                ctx.setBlendMode(.normal)
                ctx.setStrokeColor(stroke.color.cgColor)
            }
            ctx.setLineWidth(stroke.brushWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: stroke.points[0])
            stroke.points.dropFirst().forEach { ctx.addLine(to: $0) }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
