# SurfaceDrawingEditor

iOS Swift Package for interactive surface drawing and AI-powered segmentation. Provides a ready-to-use SwiftUI editor with manual brush drawing, auto-detection of walls/floors/ceilings via CoreML, and compressed image output.

---

## Requirements

- iOS 17.0+
- Swift 5.9+
- Xcode 15+

---

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**

```
https://github.com/denhryshyn-iosdev-leadsup/SurfaceDrawingEditor.git
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/denhryshyn-iosdev-leadsup/SurfaceDrawingEditor.git", from: "1.0.0")
]
```

---

## CoreML Model Setup

> ⚠️ The ML model is **not included** in the package and must be added to your app target manually.

1. Add `segformer_b2_ade20k.mlmodelc` (or `.mlpackage`) to your Xcode project
2. Make sure it's added to your **app target** (not the SPM package)
3. The detector will find it automatically via `Bundle.main`

---

## Usage

### 1. Create ViewModel

The `DrawingEditorViewModel` holds all state. Create it where you control the lifecycle — in a parent view or coordinator.

```swift
import SurfaceDrawingEditor

// Manual drawing only
@StateObject private var drawingVM = DrawingEditorViewModel(mode: .manualOnly)

// Auto-detect a surface type
@StateObject private var drawingVM = DrawingEditorViewModel(mode: .autoDetect(.wall))
```

Available surface types: `.wall`, `.floor`, `.ceiling`, `.facade`, `.door`, `.window`

---

### 2. Present the Editor

```swift
import SurfaceDrawingEditor

struct MyView: View {
    @StateObject private var drawingVM = DrawingEditorViewModel(mode: .autoDetect(.wall))
    @State private var selectedImage: UIImage?

    var body: some View {
        if let image = selectedImage {
            DrawingEditorView(
                image: image,
                vm: drawingVM,
                onHasEditsChanged: { hasEdits in
                    // enable/disable your Continue button
                },
                onDismiss: {
                    selectedImage = nil
                }
            )
        }
    }
}
```

---

### 3. Get the Result

Call `buildResult` when the user is ready (e.g. taps Continue). The result contains a compressed `UIImage` and `Data` ready for upload.

```swift
Button("Continue") {
    Task {
        guard let result = await drawingVM.buildResult(
            originalImage: image,
            canvasSize: drawingVM.lastCanvasSize
        ) else { return }

        // result.image     — UIImage, max 4096px, ≤ 10MB
        // result.imageData — Data for server upload
        uploadToServer(result.imageData)
    }
}
.disabled(!drawingVM.hasEdits)
```

---

### 4. Check for Edits

Use `hasEdits` to control UI state — e.g. enable a Continue button only when the user has drawn something or a surface was detected.

```swift
drawingVM.hasEdits // Bool — true if strokes exist or surface was auto-detected
```

---

## Modes

| Mode | Description |
|------|-------------|
| `.manualOnly` | Manual brush drawing only, no ML inference |
| `.autoDetect(.wall)` | Runs CoreML segmentation, highlights detected surface, allows manual edits |

---

## Output

`DrawingResult` contains:

```swift
public struct DrawingResult {
    public let image: UIImage     // compressed, max 4096px on longest side
    public let imageData: Data    // JPEG data, ≤ 10MB
}
```

---

## Notes

- Fonts (Inter) are bundled inside the package and registered automatically
- The ML model stays in your app bundle — it's too large for SPM versioning
- Eraser tool removes overlay while preserving the original photo underneath
- All image processing runs off the main thread
