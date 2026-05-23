//
//  ImageEditorView.swift
//  report_lms
//

import SwiftUI
import PencilKit

// MARK: - Image Editor View

struct ImageEditorView: View {
    // MARK: - Constants
    private enum Layout {
        static let toolButtonSize: CGFloat = 44
        static let toolSpacing: CGFloat = 16
        static let toolbarHPadding: CGFloat = 20
        static let toolbarVPadding: CGFloat = 10
    }

    private enum EditorTool {
        case pen, eraser, text
    }

    // MARK: - Properties
    @StateObject private var viewModel: ImageEditorViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let onSaved: (UIImage) -> Void

    @State private var canvasSize: CGSize = .zero
    @State private var activeTool: EditorTool = .pen
    @State private var showTextInput = false
    @State private var pendingText = ""
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    // MARK: - Init
    init(image: UIImage, onSaved: @escaping (UIImage) -> Void) {
        _viewModel = StateObject(wrappedValue: ImageEditorViewModel(image: image))
        self.onSaved = onSaved
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                LMSColor.black.ignoresSafeArea()
                editorCanvas
            }
            .navigationTitle(localizationManager.localize("imageEditor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LMSColor.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localize("common.cancel")) { dismiss() }
                        .foregroundColor(LMSColor.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localize("common.save")) {
                        let img = viewModel.save(canvasSize: canvasSize)
                        onSaved(img)
                        dismiss()
                    }
                    .foregroundColor(LMSColor.white)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomToolbar }
        }
        .alert(localizationManager.localize("imageEditor.addText.title"), isPresented: $showTextInput) {
            TextField(localizationManager.localize("imageEditor.addText.placeholder"), text: $pendingText)
            Button(localizationManager.localize("common.add")) {
                viewModel.addTextAnnotation(pendingText)
                pendingText = ""
            }
            Button(localizationManager.localize("common.cancel"), role: .cancel) { pendingText = "" }
        }
    }

    // MARK: - Editor Canvas
    private var editorCanvas: some View {
        GeometryReader { geo in
            let isRotated90 = (Int(viewModel.rotationAngle) / 90) % 2 != 0
            let displaySize = isRotated90
                ? CGSize(width: viewModel.sourceImage.size.height, height: viewModel.sourceImage.size.width)
                : viewModel.sourceImage.size
            let frame = aspectFitSize(for: displaySize, in: geo.size)

            ZStack {
                Image(uiImage: viewModel.sourceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width, height: frame.height)
                    .allowsHitTesting(false)

                PKCanvasViewRepresentable(canvasView: viewModel.canvasView)
                    .frame(width: frame.width, height: frame.height)

                ForEach($viewModel.textAnnotations) { $annotation in
                    DraggableTextView(annotation: $annotation) {
                        viewModel.removeAnnotation(id: annotation.id)
                    }
                }
            }
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(viewModel.rotationAngle))
            .scaleEffect(zoomScale)
            .offset(panOffset)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomScale = max(1.0, min(lastZoomScale * value, 5.0))
                    }
                    .onEnded { _ in
                        lastZoomScale = zoomScale
                        if zoomScale <= 1.0 {
                            withAnimation(.spring()) { panOffset = .zero; lastPanOffset = .zero }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard zoomScale > 1.0 else { return }
                        panOffset = CGSize(
                            width: lastPanOffset.width + value.translation.width,
                            height: lastPanOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastPanOffset = panOffset }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    zoomScale = 1.0; lastZoomScale = 1.0
                    panOffset = .zero; lastPanOffset = .zero
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear { canvasSize = frame }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = aspectFitSize(for: displaySize, in: newSize)
            }
            .onChange(of: viewModel.rotationAngle) { _, _ in
                canvasSize = aspectFitSize(for: displaySize, in: geo.size)
            }
        }
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: Layout.toolSpacing) {
            toolButton(icon: "arrow.uturn.backward", isActive: false) { viewModel.undo() }
            toolButton(icon: "arrow.uturn.forward", isActive: false) { viewModel.redo() }
            toolButton(icon: "rotate.right", isActive: false) { viewModel.rotate() }

            Spacer()

            toolButton(icon: "pencil.tip", isActive: activeTool == .pen) {
                activeTool = .pen
                viewModel.updateDrawingTool()
            }
            toolButton(icon: "eraser.fill", isActive: activeTool == .eraser) {
                activeTool = .eraser
                viewModel.switchToEraser()
            }
            toolButton(icon: "textformat", isActive: activeTool == .text) {
                activeTool = .text
                showTextInput = true
            }

            Spacer()

            if activeTool == .pen {
                ColorPicker("", selection: $viewModel.selectedColor)
                    .labelsHidden()
                    .frame(width: Layout.toolButtonSize, height: Layout.toolButtonSize)
                    .onChange(of: viewModel.selectedColor) { _, _ in
                        viewModel.updateDrawingTool()
                    }
            }
        }
        .padding(.horizontal, Layout.toolbarHPadding)
        .padding(.vertical, Layout.toolbarVPadding)
        .background(LMSColor.black.opacity(0.85))
    }

    // MARK: - Helpers
    @ViewBuilder
    private func toolButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isActive ? LMSColor.primary : LMSColor.white)
                .frame(width: Layout.toolButtonSize, height: Layout.toolButtonSize)
                .background(isActive ? LMSColor.primaryLight : Color.clear)
                .clipShape(Circle())
        })
    }

    private func aspectFitSize(for imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

// MARK: - PKCanvasView Representable

struct PKCanvasViewRepresentable: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView { canvasView }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - Draggable Text View

struct DraggableTextView: View {
    @Binding var annotation: TextAnnotation
    let onDelete: () -> Void

    @State private var dragDelta: CGSize = .zero

    var body: some View {
        Text(annotation.text)
            .font(.system(size: annotation.fontSize, weight: .bold))
            .foregroundColor(LMSColor.white)
            .shadow(color: LMSColor.black, radius: 1, x: 1, y: 1)
            .padding(6)
            .offset(
                x: annotation.offset.width + dragDelta.width,
                y: annotation.offset.height + dragDelta.height
            )
            .gesture(
                DragGesture()
                    .onChanged { v in dragDelta = v.translation }
                    .onEnded { v in
                        annotation.offset.width += v.translation.width
                        annotation.offset.height += v.translation.height
                        dragDelta = .zero
                    }
            )
            .onLongPressGesture(minimumDuration: 0.5) { onDelete() }
    }
}

// MARK: - Preview
#Preview {
    ImageEditorView(image: UIImage(systemName: "photo") ?? UIImage()) { _ in }
        .environmentObject(LocalizationManager.shared)
}
