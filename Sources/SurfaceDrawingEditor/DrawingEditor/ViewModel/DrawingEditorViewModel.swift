//
//  DrawingEditorViewModel.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 26.02.2026.
//

import SwiftUI
import Combine

@MainActor
public final class DrawingEditorViewModel: ObservableObject {
    
    // MARK: State
    
    @Published public var isProcessing    = false
    @Published public var processingStatus = ""
    @Published public var errorMessage:   String?
    
    @Published public var autoOverlayImage:    UIImage?
    @Published public var autoDetectedSurface: DetectedSurface?
    
    // Drawing
    @Published public var currentTool:  DrawingTool = .brush
    @Published public var brushWidth:   CGFloat = 40
    @Published public var eraserWidth:  CGFloat = 60
    @Published public var strokes:      [DrawingStroke] = []
    @Published public var redoStack:    [DrawingStroke] = []
    
    @Published public var isRenderingOverlay = false
    
    @Published private var _hasEdits: Bool = false
    
    // MARK: Computed
    
    public var currentWidth: CGFloat { currentTool == .brush ? brushWidth : eraserWidth }
    public var canUndo: Bool  { !strokes.isEmpty }
    public var canRedo: Bool  { !redoStack.isEmpty }
    public var hasEdits: Bool { _hasEdits }
    
    public let brushColor = UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1)
    
    public let mode: DrawingEditorMode
    
    // MARK: Private
    
    private var detector: WallFloorDetector?
    
    public init(mode: DrawingEditorMode = .manualOnly) {
        self.mode = mode
        if case .autoDetect = mode {
            isProcessing = true
            processingStatus = "Analyzing..."
        }
        detector = (try? WallFloorDetector(modelFileName: "segformer_b2_ade20k"))
    }
    
    // MARK: - Canvas size tracking
    
    private(set) public var lastCanvasSize: CGSize = .zero
    
    public func updateCanvasSize(_ size: CGSize) {
        lastCanvasSize = size
        if autoDetectedSurface != nil, autoOverlayImage == nil, !size.isEmpty {
            buildAutoOverlay(canvasSize: size)
        }
    }
    
    // MARK: - Auto Detect
    
    public func runAutoDetect(image: UIImage, type: SurfaceType) async {
        isProcessing = true
        processingStatus = "Analyzing..."
        errorMessage = nil
        autoDetectedSurface = nil
        autoOverlayImage = nil
        defer { isProcessing = false }
        
        guard let det = detector else { errorMessage = "Model not loaded"; return }
        
        do {
            let normalized = image.normalizedImage()
            let surfaces   = try await det.detect(image: normalized)
            if let matched = surfaces.first(where: { $0.type == type }) {
                autoDetectedSurface = matched
                if !lastCanvasSize.isEmpty { buildAutoOverlay(canvasSize: lastCanvasSize) }
            } else {
                errorMessage = "\(type.displayName) not detected — draw manually"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func buildAutoOverlay(canvasSize: CGSize) {
        guard let surface = autoDetectedSurface else { return }
        isRenderingOverlay = true
        Task.detached(priority: .userInitiated) { [weak self, surface] in
            let overlay = CompositeRenderer.makeAutoOverlay(surface: surface, size: canvasSize)
            await MainActor.run { [weak self] in
                self?.autoOverlayImage = overlay
                self?.isRenderingOverlay = false
                self?.recalculateHasEdits()
            }
        }
    }
    
    // MARK: - Drawing Actions
    
    public func selectTool(_ tool: DrawingTool) { currentTool = tool }
    
    public func setBrushWidth(_ w: CGFloat) {
        currentTool == .brush ? (brushWidth = w) : (eraserWidth = w)
    }
    
    public func addStroke(_ stroke: DrawingStroke) {
        strokes.append(stroke)
        redoStack.removeAll()
        recalculateHasEdits()
    }
    
    public func undo() {
        if let s = strokes.popLast() { redoStack.append(s) }
        recalculateHasEdits()
    }
    
    public func redo() {
        if let s = redoStack.popLast() { strokes.append(s) }
        recalculateHasEdits()
    }
    
    // MARK: - Helper funcs
    
    private func recalculateHasEdits() {
        let currentStrokes = strokes
        let surface = autoDetectedSurface
        let canvasSize = lastCanvasSize
        let hasAutoOverlay = autoOverlayImage != nil
        
        if currentStrokes.isEmpty && !hasAutoOverlay {
            _hasEdits = false
            return
        }
        
        Task {
            let result = await Self.calculateHasEdits(
                strokes: currentStrokes,
                surface: surface,
                canvasSize: canvasSize,
                hasAutoOverlay: hasAutoOverlay,
                mode: mode
            )
            _hasEdits = result
        }
    }
    
    private static func calculateHasEdits(
        strokes: [DrawingStroke],
        surface: DetectedSurface?,
        canvasSize: CGSize,
        hasAutoOverlay: Bool,
        mode: DrawingEditorMode
    ) async -> Bool {
        guard !canvasSize.isEmpty else { return false }
        
        return await Task.detached(priority: .userInitiated) {
            let bw: Int
            let bh: Int
            if let s = surface {
                bw = s.maskWidth
                bh = s.maskHeight
            } else {
                bw = 512
                bh = 512
            }
            
            guard let ctx = CGContext(
                data: nil,
                width: bw, height: bh,
                bitsPerComponent: 8, bytesPerRow: bw * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            
            ctx.clear(CGRect(x: 0, y: 0, width: bw, height: bh))
            
            let scaleX = CGFloat(bw) / canvasSize.width
            let scaleY = CGFloat(bh) / canvasSize.height
            
            if let s = surface, hasAutoOverlay {
                let mw = s.maskWidth, mh = s.maskHeight
                var bytes = [UInt8](repeating: 0, count: mw * mh)
                for i in s.maskIndices { bytes[i] = 255 }
                
                if let provider = CGDataProvider(data: Data(bytes) as CFData),
                   let maskCG = CGImage(
                    width: mw, height: mh, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: mw,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
                    ctx.saveGState()
                    ctx.clip(to: CGRect(x: 0, y: 0, width: bw, height: bh), mask: maskCG)
                    ctx.setFillColor(UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1).cgColor)
                    ctx.fill(CGRect(x: 0, y: 0, width: bw, height: bh))
                    ctx.restoreGState()
                }
            }
            
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            for stroke in strokes {
                guard stroke.points.count > 1 else { continue }
                let scaledWidth = stroke.brushWidth * (scaleX + scaleY) / 2
                ctx.setLineWidth(scaledWidth)
                
                if stroke.tool == .eraser {
                    ctx.setBlendMode(.clear)
                } else {
                    ctx.setBlendMode(.normal)
                    ctx.setStrokeColor(stroke.color.cgColor)
                }
                
                let pts = stroke.points.map {
                    CGPoint(x: $0.x * scaleX, y: CGFloat(bh) - $0.y * scaleY)
                }
                ctx.move(to: pts[0])
                pts.dropFirst().forEach { ctx.addLine(to: $0) }
                ctx.strokePath()
            }
            
            guard let data = ctx.data else { return false }
            let bytes = data.bindMemory(to: UInt8.self, capacity: bw * bh * 4)
            
            for i in stride(from: 3, to: bw * bh * 4, by: 4) {
                if bytes[i] > 10 { return true }
            }
            return false
        }.value
    }
    
    // MARK: - Build Result
    
    public func buildResult(originalImage: UIImage, canvasSize: CGSize) async -> DrawingResult? {
        isProcessing = true
        processingStatus = "Preparing..."
        defer { isProcessing = false }
        
        // 1. Рисуем overlay поверх оригинала
        let composite = CompositeRenderer.render(
            original: originalImage,
            autoSurface: autoDetectedSurface,
            strokes: strokes,
            canvasSize: canvasSize
        )
        
        // 2. Сжимаем до 10МБ / 4096px
        do {
            processingStatus = "Compressing..."
            let finalImage = try await ImageProcessor.process(image: composite)
            guard let data = finalImage.jpegData(compressionQuality: 0.9) else { return nil }
            return DrawingResult(image: finalImage, imageData: data)
        } catch {
            errorMessage = "Compression failed: \(error.localizedDescription)"
            return nil
        }
    }
}
