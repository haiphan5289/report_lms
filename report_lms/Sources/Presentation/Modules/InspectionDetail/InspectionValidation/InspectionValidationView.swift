//
//  InspectionValidationView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import SwiftUI

struct InspectionValidationView: View {
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let iconSize: CGFloat = 24
        static let imageGridSpacing: CGFloat = 12
        static let imageSize: CGFloat = 100
        static let bottomButtonHeight: CGFloat = 100
        static let buttonIconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 12
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: InspectionValidationViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(
        fieldId: String,
        fieldLabel: String,
        initialImages: [UIImage],
        onSave: @escaping (FieldValidation) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InspectionValidationViewModel(
                fieldId: fieldId,
                fieldLabel: fieldLabel,
                initialImages: initialImages,
                onSave: onSave
            )
        )
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    // Section 1: Header with title and camera button
                    headerSection
                    
                    // Section 2: Status and Comments
                    statusSection
                    
                    // Section 3: Image Gallery
                    if viewModel.hasImages {
                        imageGallerySection
                    }
                    
                    // Section 4: Action Buttons
                    actionsSection
                    
                    // Add bottom padding for fixed buttons
                    Spacer()
                        .frame(height: Layout.bottomButtonHeight + 20)
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Layout.horizontalPadding)
            }
            .background(Color(.systemGroupedBackground))
            
            // Fixed bottom buttons
            bottomActionsView
        }
        .navigationTitle(viewModel.fieldLabel)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(source: .inspection) { images in
                viewModel.appendImages(images)
            }
        }
        .task {
            // If no images initially, open camera directly
            if !viewModel.hasImages {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay for smooth transition
                viewModel.openCamera()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationView(
                title: "Xóa ảnh",
                message: "Bạn có chắc chắn muốn xóa ảnh này không?",
                confirmTitle: "Xóa"
            ) {
                viewModel.confirmDeleteImage()
            }
            .background(ClearBackgroundView())
        }
    }
    
    // MARK: - Section Views
    
    private var headerSection: some View {
        HStack {
            Text("Carton overview")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                viewModel.openCamera()
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: Layout.iconSize))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(LMSColor.primary)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Taking 4 sides of carton")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Divider()
            
            // Status (Trạng thái)
            VStack(alignment: .leading, spacing: 8) {
                Text("Trạng thái")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Tình trạng hiện tại")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(viewModel.status.displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(statusColor(for: viewModel.status))
                }
            }
            
            Divider()
            
            // Comments (Nhận xét)
            VStack(alignment: .leading, spacing: 8) {
                Text("Nhận xét")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextEditor(text: Binding(
                    get: { viewModel.comments },
                    set: { viewModel.updateComments($0) }
                ))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.comments.isEmpty {
                        Text("Viết nhận xét tại đây")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var imageGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Thư viện phương tiện truyền thông")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.images.count) ảnh")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if viewModel.images.isEmpty {
                Text("Chưa có ảnh nào")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.images.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            if viewModel.showReorderMode {
                                Button(action: {
                                    viewModel.requestDeleteImage(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Add more photos button
            LMSButton(
                "Chụp thêm ảnh",
                icon: "camera.fill",
                variant: .secondary,
                isFullWidth: true
            ) {
                viewModel.openCamera()
            }
            
            // Delete images button
            LMSButton(
                viewModel.showReorderMode ? "Hoàn tất" : "Xoá hình ảnh",
                icon: viewModel.showReorderMode ? "checkmark" : "trash.fill",
                variant: viewModel.showReorderMode ? .primary : .destructive,
                isFullWidth: true
            ) {
                viewModel.toggleReorderMode()
            }
        }
    }
    
    private var bottomActionsView: some View {
        HStack(spacing: 20) {
            // Button 1: Đã kiểm tra (Pass)
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.saveValidation(status: .passed)
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: Layout.buttonIconSize))
                            .foregroundColor(.green)
                    }
                }
                
                Text("Đã kiểm tra")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Button 2: Không áp dụng (Not Applicable)
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.saveValidation(status: .notApplicable)
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: Layout.buttonIconSize))
                            .foregroundColor(.gray)
                    }
                }
                
                Text("Không áp dụng")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            Color(.systemBackground)
                .shadow(color: LMSColor.shadow.opacity(0.2), radius: 8, x: 0, y: -2)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Helper Methods
    
    private func statusColor(for status: ValidationStatus) -> Color {
        switch status {
        case .passed:
            return .green
        case .failed:
            return .red
        case .pending:
            return .orange
        case .notApplicable:
            return .gray
        }
    }
}

// MARK: - Helper Views

/// Clear background view for fullScreenCover
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Preview
#Preview("With Images") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                UIImage(systemName: "photo")!,
                UIImage(systemName: "photo.fill")!,
                UIImage(systemName: "photo.circle")!,
                UIImage(systemName: "photo.circle.fill")!
            ]
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Empty State") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: []
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                UIImage(systemName: "photo")!,
                UIImage(systemName: "photo.fill")!
            ]
        ) { validation in
            print("Saved: \(validation)")
        }
    }
    .preferredColorScheme(.dark)
}
