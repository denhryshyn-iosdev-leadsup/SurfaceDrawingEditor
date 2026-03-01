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
    
    public func setHasVisibleContent(_ value: Bool) {
        _hasEdits = value
    }
    
    // MARK: - Helper funcs
    
    private func recalculateHasEdits() {
        if strokes.isEmpty {
            _hasEdits = autoOverlayImage != nil
            return
        }
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
