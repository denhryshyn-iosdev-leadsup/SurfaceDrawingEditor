//
//  ZoomableDrawingContainer.swift
//  DetectObjectsDemo
//
//  Created by _d3n_o77 on 22.02.2026.
//

import SwiftUI
import UIKit

// MARK: - ZoomableDrawingContainer
// SwiftUI View: UIKit scroll/zoom canvas + произвольный SwiftUI overlay поверх
struct ZoomableDrawingContainer: View {

    let image: UIImage
    let overlayImage: UIImage?
    let strokes: [DrawingStroke]
    let currentStroke: [CGPoint]
    let currentTool: DrawingTool
    let brushColor: UIColor
    let currentWidth: CGFloat

    var onStrokePoint: (CGPoint) -> Void
    var onStrokeEnd: () -> Void
    var onCanvasSizeKnown: ((CGSize) -> Void)? = nil
    var onContentFrameChanged: ((CGRect) -> Void)? = nil
    var onVisibleContentChanged: ((Bool) -> Void)? = nil
    
    var zoomController: ZoomController? = nil

    // MARK: ZoomController

    class ZoomController {
        weak var vc: _ZoomableDrawingVC?
        func zoomIn()  { vc?.zoomIn() }
        func zoomOut() { vc?.zoomOut() }
        func checkVisibleContent() -> Bool { vc?.drawingView.hasVisibleContent() ?? false }
    }

    // MARK: Body
    
    var body: some View {
        _ZoomableDrawingRepresentable(
            image: image,
            overlayImage: overlayImage,
            strokes: strokes,
            currentStroke: currentStroke,
            currentTool: currentTool,
            brushColor: brushColor,
            currentWidth: currentWidth,
            onStrokePoint: onStrokePoint,
            onStrokeEnd: onStrokeEnd,
            onCanvasSizeKnown: onCanvasSizeKnown,
            onContentFrameChanged: onContentFrameChanged,
            onVisibleContentChanged: onVisibleContentChanged,
            zoomController: zoomController
        )
    }
}

// MARK: - Internal UIViewControllerRepresentable
private struct _ZoomableDrawingRepresentable: UIViewControllerRepresentable {

    let image: UIImage
    let overlayImage: UIImage?
    let strokes: [DrawingStroke]
    let currentStroke: [CGPoint]
    let currentTool: DrawingTool
    let brushColor: UIColor
    let currentWidth: CGFloat
    var onStrokePoint: (CGPoint) -> Void
    var onStrokeEnd: () -> Void
    var onCanvasSizeKnown: ((CGSize) -> Void)?
    var onContentFrameChanged: ((CGRect) -> Void)?
    var onVisibleContentChanged: ((Bool) -> Void)?
    var zoomController: ZoomableDrawingContainer.ZoomController?

    func makeUIViewController(context: Context) -> _ZoomableDrawingVC {
        let vc = _ZoomableDrawingVC()
        vc.onCanvasSizeKnown = onCanvasSizeKnown
        vc.onContentFrameChanged = onContentFrameChanged
        vc.onVisibleContentChanged = onVisibleContentChanged
        zoomController?.vc = vc
        vc.configure(
            image: image, overlayImage: overlayImage,
            strokes: strokes, currentStroke: currentStroke,
            currentTool: currentTool, brushColor: brushColor, currentWidth: currentWidth,
            onStrokePoint: onStrokePoint, onStrokeEnd: onStrokeEnd
        )
        return vc
    }

    func updateUIViewController(_ vc: _ZoomableDrawingVC, context: Context) {
        zoomController?.vc = vc
        vc.onVisibleContentChanged = onVisibleContentChanged
        vc.update(
            overlayImage: overlayImage,
            strokes: strokes, currentStroke: currentStroke,
            currentTool: currentTool, brushColor: brushColor, currentWidth: currentWidth,
            onStrokePoint: onStrokePoint, onStrokeEnd: onStrokeEnd
        )
    }
}

// MARK: - ViewController

final class _ZoomableDrawingVC: UIViewController {

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let imageView   = UIImageView()
    private(set) var drawingView = _DrawingCanvasUIView()
    
    private var scrollViewWidthConstraint:  NSLayoutConstraint?
    private var scrollViewHeightConstraint: NSLayoutConstraint?

    private var onStrokePoint: ((CGPoint) -> Void)?
    private var onStrokeEnd:   (() -> Void)?
    var onCanvasSizeKnown: ((CGSize) -> Void)?
    var onContentFrameChanged: ((CGRect) -> Void)?
    var onVisibleContentChanged: ((Bool) -> Void)?

    func zoomIn() {
        scrollView.setZoomScale(min(scrollView.zoomScale * 1.5, scrollView.maximumZoomScale), animated: true)
    }

    func zoomOut() {
        let s = max(scrollView.zoomScale / 1.5, scrollView.minimumZoomScale)
        scrollView.setZoomScale(s, animated: true)
        if s <= scrollView.minimumZoomScale {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.centerContent() }
        }
    }

    func configure(
        image: UIImage, overlayImage: UIImage?,
        strokes: [DrawingStroke], currentStroke: [CGPoint],
        currentTool: DrawingTool, brushColor: UIColor, currentWidth: CGFloat,
        onStrokePoint: @escaping (CGPoint) -> Void, onStrokeEnd: @escaping () -> Void
    ) {
        self.onStrokePoint = onStrokePoint
        self.onStrokeEnd   = onStrokeEnd
        imageView.image           = image
        drawingView.overlayImage  = overlayImage
        drawingView.strokes       = strokes
        drawingView.currentStroke = currentStroke
        drawingView.currentTool   = currentTool
        drawingView.brushColor    = brushColor
        drawingView.currentWidth  = currentWidth
    }

    func update(
        overlayImage: UIImage?,
        strokes: [DrawingStroke], currentStroke: [CGPoint],
        currentTool: DrawingTool, brushColor: UIColor, currentWidth: CGFloat,
        onStrokePoint: @escaping (CGPoint) -> Void, onStrokeEnd: @escaping () -> Void
    ) {
        let strokesChanged = drawingView.strokes.count != strokes.count
        let overlayChanged = drawingView.overlayImage !== overlayImage
        
        self.onStrokePoint = onStrokePoint
        self.onStrokeEnd   = onStrokeEnd
        drawingView.overlayImage  = overlayImage
        drawingView.strokes       = strokes
        drawingView.currentStroke = currentStroke
        drawingView.currentTool   = currentTool
        drawingView.brushColor    = brushColor
        drawingView.currentWidth  = currentWidth
        drawingView.setNeedsDisplay()
        
        if strokesChanged || overlayChanged {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let hasContent = self.drawingView.hasVisibleContent()
                self.onVisibleContentChanged?(hasContent)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupScrollView()
        setupContentView()
        setupDrawingGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentSize()
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom    = true
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.layer.cornerRadius = 20
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        setupZoomButtons()
        
        scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        scrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        scrollViewWidthConstraint  = scrollView.widthAnchor.constraint(equalToConstant: 100)
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 100)
        scrollViewWidthConstraint?.isActive  = true
        scrollViewHeightConstraint?.isActive = true
    }

    private func setupContentView() {
        contentView.backgroundColor     = .clear
        contentView.layer.cornerRadius  = 20
        contentView.layer.masksToBounds = true
        scrollView.addSubview(contentView)

        imageView.contentMode     = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        drawingView.backgroundColor = .clear
        drawingView.isOpaque        = false
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(drawingView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            drawingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            drawingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            drawingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func updateContentSize() {
        guard let img = imageView.image, view.bounds.width > 0 else { return }
        let vW = view.bounds.width, vH = view.bounds.height
        let ia = img.size.width / img.size.height
        let va = vW / vH
        let cW: CGFloat, cH: CGFloat
        if ia > va { cW = vW; cH = vW / ia } else { cH = vH; cW = vH * ia }
        
        scrollViewWidthConstraint?.constant  = cW
        scrollViewHeightConstraint?.constant = cH
        view.layoutIfNeeded()

        contentView.frame      = CGRect(x: 0, y: 0, width: cW, height: cH)
        scrollView.contentSize = CGSize(width: cW, height: cH)
        centerContent()

        let sz = CGSize(width: cW, height: cH)
        drawingView.canvasSize = sz
        onCanvasSizeKnown?(sz)
    }

    private func centerContent() {
        let ox = max((scrollView.bounds.width  - scrollView.contentSize.width)  / 2, 0)
        let oy = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: oy, left: ox, bottom: oy, right: ox)
        let cW = scrollView.contentSize.width
        let cH = scrollView.contentSize.height
        if cW > 0, cH > 0 {
            onContentFrameChanged?(CGRect(x: ox, y: oy, width: cW, height: cH))
        }
    }

    private func setupDrawingGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDraw(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        drawingView.addGestureRecognizer(pan)
    }
    
    private func setupZoomButtons() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let zoomIn  = makeZoomButton(imageName: "zoom_in_ic",  action: #selector(zoomInTapped))
        let zoomOut = makeZoomButton(imageName: "zoom_out_ic", action: #selector(zoomOutTapped))
        
        stack.addArrangedSubview(zoomIn)
        stack.addArrangedSubview(zoomOut)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
        ])
    }

    private func makeZoomButton(imageName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(named: imageName, in: .module, compatibleWith: nil), for: .normal)
        btn.imageView?.contentMode = .scaleAspectFit
        btn.translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = 32
        btn.widthAnchor.constraint(equalToConstant: FigmaLayoutScaler.scaleWidth(size)).isActive = true
        btn.heightAnchor.constraint(equalToConstant: FigmaLayoutScaler.scaleHeight(size)).isActive = true
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    @objc private func zoomInTapped()  { zoomIn() }
    @objc private func zoomOutTapped() { zoomOut() }

    @objc private func handleDraw(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: drawingView)
        switch g.state {
        case .began:
            drawingView.showCursor(at: pt)
        case .changed:
            onStrokePoint?(pt)
            drawingView.showCursor(at: pt)
        case .ended, .cancelled:
            onStrokePoint?(pt)
            onStrokeEnd?()
            drawingView.hideCursor()
        default:
            drawingView.hideCursor()
        }
    }
}

extension _ZoomableDrawingVC: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }
}

extension _ZoomableDrawingVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other is UIPinchGestureRecognizer
    }
}

// MARK: - _DrawingCanvasUIView

final class _DrawingCanvasUIView: UIView {

    var overlayImage:  UIImage?
    var strokes:       [DrawingStroke] = []
    var currentStroke: [CGPoint] = []
    var currentTool:   DrawingTool = .brush
    var brushColor:    UIColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.4)
    var currentWidth:  CGFloat = 40
    var canvasSize:    CGSize  = .zero

    private var outerCursorLayer: CAShapeLayer?
    private var innerCursorLayer: CAShapeLayer?
    private var centerCursorLayer: CAShapeLayer?

    func showCursor(at point: CGPoint) {
        if outerCursorLayer == nil {
            let outer = CAShapeLayer()
            outer.fillColor = UIColor.white.cgColor
            outer.strokeColor = UIColor.clear.cgColor
            outer.zPosition = 100
            layer.addSublayer(outer)
            outerCursorLayer = outer
        }
        if innerCursorLayer == nil {
            let inner = CAShapeLayer()
            inner.fillColor = UIColor(white: 0.55, alpha: 1).cgColor
            inner.strokeColor = UIColor.clear.cgColor
            inner.zPosition = 101
            layer.addSublayer(inner)
            innerCursorLayer = inner
        }
        // + третий слой — белый центр
        if centerCursorLayer == nil {
            let center = CAShapeLayer()
            center.fillColor = UIColor.white.cgColor
            center.zPosition = 102
            layer.addSublayer(center)
            centerCursorLayer = center
        }

        let r = currentWidth / 2
        let outerRect = CGRect(x: point.x - r, y: point.y - r, width: currentWidth, height: currentWidth)

        let grayInset   = currentWidth * 0.12   // ~12% от радиуса
        let centerInset = currentWidth * 0.28   // ~28% от радиуса

        outerCursorLayer?.path  = UIBezierPath(ovalIn: outerRect).cgPath
        innerCursorLayer?.path  = UIBezierPath(ovalIn: outerRect.insetBy(dx: grayInset, dy: grayInset)).cgPath
        centerCursorLayer?.path = UIBezierPath(ovalIn: outerRect.insetBy(dx: centerInset, dy: centerInset)).cgPath
        
        outerCursorLayer?.isHidden = false
        innerCursorLayer?.isHidden = false
        centerCursorLayer?.isHidden = false
    }

    func hideCursor() {
        outerCursorLayer?.isHidden = true
        innerCursorLayer?.isHidden = true
        centerCursorLayer?.isHidden = true
    }
    
    func hasVisibleContent() -> Bool {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return false }

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return false }

        ctx.clear(CGRect(origin: .zero, size: size))
        overlayImage?.draw(in: bounds)
        strokes.forEach { drawStroke($0, in: ctx) }

        guard let uiImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = uiImage.cgImage,
              let dataProvider = cgImage.dataProvider,
              let cfData = dataProvider.data else { return false }

        let length = CFDataGetLength(cfData)
        guard let bytes = CFDataGetBytePtr(cfData) else { return false }

        var i = 3
        while i < length {
            if bytes[i] > 5 { return true }
            i += 4 * 4
        }
        return false
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        overlayImage?.draw(in: bounds)
        strokes.forEach { drawStroke($0, in: ctx) }
        if currentStroke.count > 1 { drawLiveStroke(in: ctx) }
    }

    private func drawStroke(_ stroke: DrawingStroke, in ctx: CGContext) {
        guard stroke.points.count > 1 else { return }
        if stroke.tool == .eraser {
            ctx.saveGState(); ctx.setBlendMode(.clear)
            self.stroke(stroke.points, width: stroke.brushWidth, color: .white, ctx: ctx)
            ctx.restoreGState()
        } else {
            offscreen(points: stroke.points, width: stroke.brushWidth,
                      color: stroke.color, alpha: stroke.color.cgColor.alpha, ctx: ctx)
        }
    }

    private func drawLiveStroke(in ctx: CGContext) {
        guard currentStroke.count > 1 else { return }
        if currentTool == .eraser {
            ctx.saveGState(); ctx.setBlendMode(.clear)
            stroke(currentStroke, width: currentWidth, color: .white, ctx: ctx)
            ctx.restoreGState()
        } else {
            offscreen(points: currentStroke, width: currentWidth,
                      color: brushColor, alpha: brushColor.cgColor.alpha, ctx: ctx)
        }
    }

    private func stroke(_ pts: [CGPoint], width: CGFloat, color: UIColor, ctx: CGContext) {
        ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(width)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.move(to: pts[0]); pts.dropFirst().forEach { ctx.addLine(to: $0) }
        ctx.strokePath()
    }

    private func offscreen(points: [CGPoint], width: CGFloat, color: UIColor, alpha: CGFloat, ctx: CGContext) {
        let sz = bounds.size
        guard let off = CGContext(data: nil, width: Int(sz.width), height: Int(sz.height),
                                   bitsPerComponent: 8, bytesPerRow: Int(sz.width) * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        off.setStrokeColor(color.withAlphaComponent(1.0).cgColor)
        off.setLineWidth(width); off.setLineCap(.round); off.setLineJoin(.round)
        off.move(to: points[0]); points.dropFirst().forEach { off.addLine(to: $0) }
        off.strokePath()
        if let img = off.makeImage() {
            ctx.saveGState(); ctx.setAlpha(alpha); ctx.draw(img, in: bounds); ctx.restoreGState()
        }
    }
}
