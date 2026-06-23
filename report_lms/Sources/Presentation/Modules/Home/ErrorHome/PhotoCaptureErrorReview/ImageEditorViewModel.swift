//
//  ImageEditorViewModel.swift
//  report_lms
//

import SwiftUI
import PencilKit
import OSLog

// MARK: - Text Annotation Model

struct TextAnnotation: Identifiable {
    let id = UUID()
    var text: String
    var offset: CGSize = .zero
    let fontSize: CGFloat = 20
}

// MARK: - Image Editor ViewModel

@MainActor
final class ImageEditorViewModel: ObservableObject {
    // MARK: - Published
    @Published var textAnnotations: [TextAnnotation] = []
    @Published var selectedColor: Color = .red
    @Published var inkWidth: CGFloat = 5
    @Published var rotationAngle: Double = 0

    // MARK: - Properties
    let sourceImage: UIImage
    let canvasView = PKCanvasView()
    private let logger = Logger(subsystem: "com.reportlms", category: "ImageEditorViewModel")

    var currentInkingTool: PKInkingTool {
        PKInkingTool(.pen, color: UIColor(selectedColor), width: inkWidth)
    }

    // MARK: - Init
    init(image: UIImage) {
        print("🔍 [ImageEditorViewModel] Init")
        print("   - Source image size: \(image.size)")
        print("   - Source image scale: \(image.scale)")
        self.sourceImage = image
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        canvasView.isScrollEnabled = false   // SwiftUI MagnificationGesture owns zoom
        canvasView.tool = PKInkingTool(.pen, color: UIColor(.red), width: 5)
    }

    // MARK: - Tool Management
    func updateDrawingTool() {
        canvasView.tool = currentInkingTool
    }

    func switchToEraser() {
        canvasView.tool = PKEraserTool(.bitmap)
    }

    func undo() { canvasView.undoManager?.undo() }
    func redo() { canvasView.undoManager?.redo() }
    func rotate() { rotationAngle += 90 }

    // MARK: - Text Annotations
    func addTextAnnotation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        textAnnotations.append(TextAnnotation(text: trimmed))
    }

    func removeAnnotation(id: UUID) {
        textAnnotations.removeAll { $0.id == id }
    }

    // MARK: - Save
    func save(canvasSize: CGSize) -> UIImage {
        print("🔍 [ImageEditorViewModel] save() called")
        print("   - canvasSize: \(canvasSize)")
        print("   - sourceImage size: \(sourceImage.size)")
        let result = compositeImage(canvasSize: canvasSize)
        print("   - Result image size: \(result.size)")
        return result
    }

    // MARK: - Private

    private func rotatedSourceImage() -> UIImage {
        let steps = (Int(rotationAngle) / 90) % 4
        guard steps != 0 else { return sourceImage }

        // Step 1: normalize orientation to .up so that UIImage.size == pixel dimensions.
        // Camera photos have imageOrientation == .right (pixels stored landscape, displayed portrait).
        // UIGraphicsImageRenderer respects imageOrientation when drawing, producing a physically
        // correct .up image whose size matches what the user sees on screen.
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let normalized: UIImage
        if sourceImage.imageOrientation == .up {
            normalized = sourceImage
        } else {
            normalized = UIGraphicsImageRenderer(size: sourceImage.size, format: fmt).image { _ in
                sourceImage.draw(in: CGRect(origin: .zero, size: sourceImage.size))
            }
        }

        // Step 2: physically rotate pixels by steps * 90° CW using CGContext transform.
        // This ensures UIImage.size reflects the rotated dimensions so compositeImage()
        // uses a uniform scaleX == scaleY when mapping canvas strokes to the output image.
        let isSwap = steps % 2 == 1
        let newSize = isSwap
            ? CGSize(width: normalized.size.height, height: normalized.size.width)
            : normalized.size

        let result = UIGraphicsImageRenderer(size: newSize, format: fmt).image { ctx in
            let cg = ctx.cgContext
            switch steps {
            case 1: // 90° CW
                cg.translateBy(x: newSize.width, y: 0)
                cg.rotate(by: .pi / 2)
            case 2: // 180°
                cg.translateBy(x: newSize.width, y: newSize.height)
                cg.rotate(by: .pi)
            case 3: // 270° CW (= 90° CCW)
                cg.translateBy(x: 0, y: newSize.height)
                cg.rotate(by: -.pi / 2)
            default: break
            }
            normalized.draw(in: CGRect(origin: .zero, size: normalized.size))
        }
        print("🔍 [ImageEditorViewModel] rotatedSourceImage() — steps=\(steps), size \(sourceImage.size) → \(result.size)")
        return result
    }

    private func compositeImage(canvasSize: CGSize) -> UIImage {
        print("🔍 [ImageEditorViewModel] compositeImage()")
        let base = rotatedSourceImage()
        let imgSize = base.size
        print("   - Base image size: \(imgSize)")
        print("   - Canvas size: \(canvasSize)")
        
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            print("   - ⚠️ canvasSize is zero, returning base image")
            return base
        }
        
        let scaleX = imgSize.width / canvasSize.width
        let scaleY = imgSize.height / canvasSize.height
        print("   - Scale: (\(scaleX), \(scaleY))")
        let renderer = UIGraphicsImageRenderer(size: imgSize)

        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: imgSize))

            let drawingImage = canvasView.drawing.image(
                from: CGRect(origin: .zero, size: canvasSize),
                scale: UIScreen.main.scale
            )
            drawingImage.draw(in: CGRect(origin: .zero, size: imgSize))

            for annotation in textAnnotations {
                let scaledFont = annotation.fontSize * scaleX
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: scaledFont, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .strokeColor: UIColor.black,
                    .strokeWidth: -2
                ]
                let charWidth = scaledFont * 0.6
                let x = (canvasSize.width / 2 + annotation.offset.width) * scaleX
                    - (charWidth * CGFloat(annotation.text.count)) / 2
                let y = (canvasSize.height / 2 + annotation.offset.height) * scaleY
                    - scaledFont / 2
                annotation.text.draw(at: CGPoint(x: max(0, x), y: max(0, y)), withAttributes: attrs)
            }
        }
    }

}
