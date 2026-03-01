//
//  DrawingEditorView.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 24.02.2026.
//

import SwiftUI
import UIKit

// MARK: - DrawingEditorView
public struct DrawingEditorView: View {

    public let image:     UIImage
    @ObservedObject public var vm: DrawingEditorViewModel
    public var onHasEditsChanged: ((Bool) -> Void)? = nil
    public var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var currentStroke: [CGPoint] = []
    @State private var canvasSize:    CGSize    = .zero
    @State private var contentFrame:  CGRect    = .zero
    @State private var zoomController = ZoomableDrawingContainer.ZoomController()
    
    public init(
        image: UIImage,
        vm: DrawingEditorViewModel,
        onHasEditsChanged: ((Bool) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.image = image
        self.vm = vm
        self.onHasEditsChanged = onHasEditsChanged
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: FigmaLayoutScaler.scaleHeight(24)) {
                canvas
                toolbar
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            FontRegistrar.registerIfNeeded()
            startIfNeeded()
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZoomableDrawingContainer(
            image: image,
            overlayImage: vm.autoOverlayImage,
            strokes: vm.strokes,
            currentStroke: currentStroke,
            currentTool: vm.currentTool,
            brushColor: vm.brushColor,
            currentWidth: vm.currentWidth,
            onStrokePoint: { currentStroke.append($0) },
            onStrokeEnd: {
                guard !currentStroke.isEmpty else { return }
                vm.addStroke(DrawingStroke(
                    points: currentStroke,
                    tool: vm.currentTool,
                    brushWidth: vm.currentWidth,
                    color: vm.brushColor
                ))
                currentStroke = []
            },
            onCanvasSizeKnown: { size in
                canvasSize = size
                vm.updateCanvasSize(size)
            },
            onContentFrameChanged: { contentFrame = $0 },
            onVisibleContentChanged: { hasContent in
                vm.setHasVisibleContent(hasContent)
            },
            zoomController: zoomController
        )
        .clipped()
        .overlay {
            if vm.isProcessing || vm.isRenderingOverlay {
                ZStack {
                    Color.black.opacity(0.15)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
                .frame(width: contentFrame.width, height: contentFrame.height)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .onChange(of: vm.hasEdits) { _, newValue in
            onHasEditsChanged?(newValue)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        toolbarContent
            .background(.clear)
    }

    private var processingRow: some View {
        HStack(spacing: FigmaLayoutScaler.scaleWidth(10)) {
            ProgressView().tint(DrawingDesign.accentSwiftUI)
            Text(vm.processingStatus)
                .appFont(.regular, 14)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FigmaLayoutScaler.scaleHeight(20))
    }

    private var toolbarContent: some View {
        VStack(spacing: FigmaLayoutScaler.scaleHeight(14)) {
            if let err = vm.errorMessage { errorBanner(err) }
            
            HStack {
                HStack(spacing: FigmaLayoutScaler.scaleWidth(10)) {
                    toolButton(.brush)
                    toolButton(.eraser)
                }
                Spacer()
                HStack(spacing: FigmaLayoutScaler.scaleWidth(4)) {
                    undoRedoBtn(activeIcon: "draw_back_active_ic",
                                inactiveIcon: "draw_back_inactive_ic",
                                enabled: vm.canUndo) {
                        vm.undo()
                        DispatchQueue.main.async {
                            let hasContent = zoomController.checkVisibleContent()
                            vm.setHasVisibleContent(hasContent)
                        }
                    }
                    undoRedoBtn(activeIcon: "draw_for_active_ic",
                                inactiveIcon: "draw_for_inactive_ic",
                                enabled: vm.canRedo) {
                        vm.redo()
                        DispatchQueue.main.async {
                            let hasContent = zoomController.checkVisibleContent()
                            vm.setHasVisibleContent(hasContent)
                        }
                    }
                }
            }
            .padding(.horizontal, FigmaLayoutScaler.scaleWidth(20))
            .padding(.top, FigmaLayoutScaler.scaleHeight(16))

            brushWidthRow
            Spacer(minLength: 0)
        }
        .padding(.bottom, safeAreaBottom)
    }

    private var brushWidthRow: some View {
        VStack(alignment: .leading, spacing: FigmaLayoutScaler.scaleHeight(16)) {
            Text("Brush width")
                .appFont(.semibold, 16)
                .foregroundStyle(Color(hex: "#1F2024"))

            BrushSlider(
                value: Binding(get: { vm.currentWidth }, set: { vm.setBrushWidth($0) }),
                range: 10...100
            )
        }
        .padding(.horizontal, FigmaLayoutScaler.scaleWidth(20))
        .padding(.bottom, FigmaLayoutScaler.scaleHeight(4))
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: FigmaLayoutScaler.scaleWidth(8)) {
            Image(systemName: "info.circle").foregroundStyle(.orange)
            Text(text).appFont(.regular, 13).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, FigmaLayoutScaler.scaleWidth(20))
        .padding(.top, FigmaLayoutScaler.scaleHeight(4))
    }
    
    // MARK: - Tool Buttons
    
    private func toolButton(_ tool: DrawingTool) -> some View {
        return Button { vm.selectTool(tool) } label: {
            Image(vm.currentTool == tool ? tool.activeIcon : tool.inactiveIcon, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(
                    width:  FigmaLayoutScaler.scaleWidth(32),
                    height: FigmaLayoutScaler.scaleHeight(32)
                )
        }
        .animation(.easeInOut(duration: 0.15), value: vm.currentTool == tool)
    }

    private func undoRedoBtn(activeIcon: String, inactiveIcon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image(enabled ? activeIcon : inactiveIcon, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(
                    width:  FigmaLayoutScaler.scaleWidth(32),
                    height: FigmaLayoutScaler.scaleHeight(32)
                )
        }
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.1), value: enabled)
    }

    // MARK: - Helpers

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    private func startIfNeeded() {
        if case .autoDetect(let type) = vm.mode {
            Task { await vm.runAutoDetect(image: image, type: type) }
        }
    }

    public var hasEdits: Bool { vm.hasEdits }
    
    // Быстрый превью без сжатия — синхронный
    public var currentPreviewImage: UIImage? {
        guard !canvasSize.isEmpty else { return nil }
        return CompositeRenderer.render(
            original: image,
            autoSurface: vm.autoDetectedSurface,
            strokes: vm.strokes,
            canvasSize: canvasSize
        )
    }

    public func generateResult() async -> DrawingResult? {
        guard !canvasSize.isEmpty else { return nil }
        return await vm.buildResult(originalImage: image, canvasSize: canvasSize)
    }
}
