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
        var orientation: UIImage.Orientation
        switch steps {
        case 1: orientation = .right
        case 2: orientation = .down
        case 3: orientation = .left
        default: return sourceImage
        }
        guard let cgImage = sourceImage.cgImage else { return sourceImage }
        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: orientation)
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
