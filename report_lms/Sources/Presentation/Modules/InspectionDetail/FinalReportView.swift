//
//  FinalReportView.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import SwiftUI

struct FinalReportView: View {
    // MARK: - Constants
    private enum Layout {
        static let sectionSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 12
        static let iconSize: CGFloat = 20
        static let actionButtonHeight: CGFloat = 56
        static let savePhotoButtonHeight: CGFloat = 50
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: FinalReportViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(
        inspectionDetail: InspectionDetail?,
        capturedPhotos: [String: [UIImage]]
    ) {
        _viewModel = StateObject(wrappedValue: FinalReportViewModel(
            inspectionDetail: inspectionDetail,
            capturedPhotos: capturedPhotos
        ))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: Layout.sectionSpacing) {
                    // Section 1: Số lượng
                    quantitiesSection
                    
                        statusSection
                        
                        // Section 2: Vị trí
                        locationSection
                        
                        // Section 3: Tóm tắt nhận xét
                        summarySection
                        
                        // Section 4: Thông báo
                        notificationSection
                        
                        // Section 5: Kết thúc kiểm tra
                        actionButtonsSection
                        
                        // Section 6: Lưu vào tập ảnh
                        savePhotosSection
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical, Layout.verticalPadding)
                }
            }
            .navigationTitle("Hoàn tất kiểm tra")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(LMSColor.textPrimary)
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingRecipientsPicker) {
            recipientsPickerView
        }
        .sheet(isPresented: $viewModel.isShowingMailComposer) {
            if let pdfData = viewModel.pdfData {
                MailComposerView(
                    pdfData: pdfData,
                    inspectionNumber: viewModel.inspectionDetail?.inspectionNumber ?? "",
                    onComplete: { result in
                        if result == .sent {
                            viewModel.handleEmailSent()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingPDFPreview) {
            if let pdfData = viewModel.pdfData {
                PDFPreviewView(
                    pdfData: pdfData,
                    fileName: "Bao_cao_kiem_tra_\(viewModel.inspectionDetail?.inspectionNumber ?? "").pdf"
                )
            }
        }
        .overlay {
            if viewModel.isGeneratingPDF {
                LoadingOverlayView(message: "Đang tạo PDF...")
            } else if viewModel.isSavingPhotos {
                LoadingOverlayView(message: "Đang lưu ảnh...")
            }
        }
        .overlay {
            if viewModel.showEmailSuccessAlert {
                SuccessConfirmationView(
                    title: "Gửi thành công",
                    message: "Email báo cáo đã được gửi",
                    confirmTitle: "OK"
                ) {
                    viewModel.showEmailSuccessAlert = false
                }
            }
            
            if viewModel.showPhotoSaveSuccess {
                SuccessConfirmationView(
                    title: "Lưu thành công",
                    message: "Đã lưu \(viewModel.totalPhotosCount) ảnh vào thư viện",
                    confirmTitle: "OK"
                ) {
                    viewModel.showPhotoSaveSuccess = false
                }
            }
        }
        .alert("Lỗi", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { }
        } message: {
            if let error = viewModel.errorAlertMessage {
                Text(error)
            }
        }
        .alert("Lỗi lưu ảnh", isPresented: $viewModel.showPhotoSaveError) {
            Button("OK") { }
        } message: {
            if let error = viewModel.photoSaveErrorMessage {
                Text(error)
            }
        }
        .alert("Email không khả dụng", isPresented: $viewModel.showMailUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Thiết bị này chưa được cấu hình email. Vui lòng thiết lập tài khoản email trong Cài đặt.")
        }
    }
    
    // MARK: - Section Views
    
    private var quantitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Số lượng", style: .headline)
            
            VStack(spacing: 8) {
                InfoRowView(
                    label: "Số lượng đơn hàng",
                    value: "\(viewModel.inspectionDetail?.orderQuantity ?? 0)"
                )
                
                InfoRowView(
                    label: "Số lượng thực tế đã xong",
                    value: "\(viewModel.inspectionDetail?.actualCompletedQuantity ?? 0)"
                )
                
                InfoRowView(
                    label: "Số lượng cần kiểm tra theo AQL",
                    value: "\(viewModel.inspectionDetail?.aqlInspectionQuantity ?? 0)"
                )
                
                InfoRowView(
                    label: "Số lượng đã kiểm tra",
                    value: "\(viewModel.inspectionDetail?.inspectedQuantity ?? 0)"
                )
            }
        }
        .padding()
        .background(LMSColor.white)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Trạng thái", style: .headline)
            
            Picker("Trạng thái", selection: $viewModel.selectedStatus) {
                ForEach(FinalReportStatus.allCases, id: \.self) { status in
                    Label {
                        Text(status.displayName)
                    } icon: {
                        Image(systemName: status.iconName)
                    }
                    .tag(status)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(LMSColor.white)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Vị trí", style: .headline)
            
            TextField("Nhập vị trí kiểm tra", text: $viewModel.location)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .font(.system(size: 15))
        }
        .padding()
        .background(LMSColor.white)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Tóm tắt nhận xét", style: .headline)
            
            TextEditor(text: $viewModel.summaryComments)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding()
        .background(LMSColor.white)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                viewModel.toggleNotificationSection()
            }) {
                HStack {
                    LMSLabel("Thông báo (\(viewModel.recipientsCount))", style: .headline)
                    
                    Spacer()
                    
                    Image(systemName: viewModel.isNotificationSectionExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(LMSColor.textSecondary)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            
            if viewModel.isNotificationSectionExpanded {
                // Info Text
                Text("Khi báo cáo đã hoàn tất và được tải lên, email thông báo sẽ được gửi tới")
                    .font(.system(size: 14))
                    .foregroundColor(LMSColor.textSecondary)
                    .padding(.top, 4)
                
                // Selected Recipients List
                if !viewModel.selectedRecipients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.selectedRecipients) { recipient in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(LMSColor.primary)
                                Text(recipient.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(LMSColor.textPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Add Button
                Button(action: {
                    viewModel.isShowingRecipientsPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: Layout.iconSize))
                            .foregroundColor(LMSColor.primary)
                        
                        Text("Thêm")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LMSColor.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(LMSColor.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LMSColor.primaryBorder, lineWidth: 1.5)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(LMSColor.white)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Kết thúc kiểm tra", style: .headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Preview PDF Button
                Button(action: {
                    Task {
                        await viewModel.generateAndPreviewPDF()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: Layout.iconSize, weight: .medium))
                            .foregroundColor(LMSColor.primary)
                        
                        Text("Xem PDF")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LMSColor.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.actionButtonHeight)
                    .background(LMSColor.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .stroke(LMSColor.primaryBorder, lineWidth: 1.5)
                    )
                    .cornerRadius(Layout.cornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGeneratingPDF)
                .opacity(viewModel.isGeneratingPDF ? 0.6 : 1.0)
                
                // Send Email Button
                Button(action: {
                    Task {
                        await viewModel.generateAndSendPDF()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: Layout.iconSize, weight: .medium))
                            .foregroundColor(LMSColor.white)
                        
                        Text("Gửi Email")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LMSColor.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.actionButtonHeight)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [LMSColor.primary, LMSColor.primary.opacity(0.85)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(Layout.cornerRadius)
                    .shadow(color: LMSColor.primary.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGeneratingPDF)
                .opacity(viewModel.isGeneratingPDF ? 0.6 : 1.0)
            }
            .padding(.horizontal)
        }
    }
    
    private var savePhotosSection: some View {
        Button(action: {
            Task {
                await viewModel.saveAllPhotosToLibrary()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: Layout.iconSize, weight: .medium))
                    .foregroundColor(LMSColor.white)
                
                Text("Lưu vào tập ảnh (\(viewModel.totalPhotosCount))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LMSColor.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.savePhotoButtonHeight)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [LMSColor.secondary, LMSColor.secondary.opacity(0.85)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(Layout.cornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingPhotos || viewModel.totalPhotosCount == 0)
        .opacity(viewModel.totalPhotosCount == 0 ? 0.5 : 1.0)
    }
    
    private var recipientsPickerView: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableRecipients) { recipient in
                    Button(action: {
                        viewModel.toggleRecipient(recipient)
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(LMSColor.primary)
                                .font(.system(size: 24))
                            
                            Text(recipient.name)
                                .font(.system(size: 16))
                                .foregroundColor(LMSColor.textPrimary)
                            
                            Spacer()
                            
                            if viewModel.isRecipientSelected(recipient) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(LMSColor.primary)
                                    .font(.system(size: 24))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Chọn người nhận")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        viewModel.isShowingRecipientsPicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct InfoRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LMSLabel(label, style: .body, color: .secondary)
            
            Spacer()
            
            LMSLabel(value, style: .body, color: .primary)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Loading Overlay
private struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

// MARK: - Preview
#Preview {
    FinalReportView(
        inspectionDetail: InspectionDetail.mock(inspectionId: "1", inspectionNumber: "001"),
        capturedPhotos: ["field1": [UIImage(systemName: "photo")].compactMap { $0 }]
    )
}
