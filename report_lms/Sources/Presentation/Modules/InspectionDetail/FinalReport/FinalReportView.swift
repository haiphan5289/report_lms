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
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: FinalReportViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(
        inspection: Inspection?,
        capturedPhotos: [String: [InspectionImage]]
    ) {
        _viewModel = StateObject(wrappedValue: FinalReportViewModel(
            inspection: inspection,
            capturedPhotos: capturedPhotos
        ))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                LMSColor.backgroundGrouped
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
                    inspectionNumber: viewModel.inspection?.inspectionNumber ?? "",
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
                    fileName: "Bao_cao_kiem_tra_\(viewModel.inspection?.inspectionNumber ?? "").pdf"
                )
            }
        }
        .overlay {
            if viewModel.isGeneratingPDF {
                LMSLoadingOverlay(message: "Đang tạo PDF...", style: .dark)
            } else if viewModel.isSavingPhotos {
                LMSLoadingOverlay(message: "Đang lưu ảnh...", style: .dark)
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
        LMSSectionContainer(title: "Số lượng") {
            VStack(spacing: 8) {
                LMSInfoRow(
                    label: "Số lượng đơn hàng",
                    value: "\(viewModel.inspection?.orderQuantity ?? 0)"
                )
                
                LMSInfoRow(
                    label: "Số lượng thực tế đã xong",
                    value: "\(viewModel.inspection?.actualCompletedQuantity ?? 0)"
                )
                
                LMSInfoRow(
                    label: "Số lượng cần kiểm tra theo AQL",
                    value: "\(viewModel.inspection?.aqlInspectionQuantity ?? 0)"
                )
                
                LMSInfoRow(
                    label: "Số lượng đã kiểm tra",
                    value: "\(viewModel.inspection?.inspectedQuantity ?? 0)"
                )
            }
        }
    }
    
    private var statusSection: some View {
        LMSSectionContainer(title: "Trạng thái") {
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
            .background(LMSColor.backgroundSecondary)
            .cornerRadius(8)
        }
    }
    
    private var locationSection: some View {
        LMSSectionContainer(title: "Vị trí") {
            TextField("Nhập vị trí kiểm tra", text: $viewModel.location)
                .padding(12)
                .background(LMSColor.backgroundSecondary)
                .cornerRadius(8)
                .font(.system(size: 15))
        }
    }
    
    private var summarySection: some View {
        LMSSectionContainer(title: "Tóm tắt nhận xét") {
            TextEditor(text: $viewModel.summaryComments)
                .frame(minHeight: 120)
                .padding(8)
                .background(LMSColor.backgroundSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LMSColor.secondary, lineWidth: 1)
                )
        }
    }
    
    private var notificationSection: some View {
        LMSSectionContainer {
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
                    LMSLabel(
                        "Khi báo cáo đã hoàn tất và được tải lên, email thông báo sẽ được gửi tới",
                        style: .caption,
                        color: .secondary
                    )
                    .padding(.top, 4)
                    
                    // Selected Recipients List
                    if !viewModel.selectedRecipients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.selectedRecipients) { recipient in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(LMSColor.primary)
                                    LMSLabel(recipient.name, style: .body, color: .primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Add Button
                    LMSButton(
                        "Thêm",
                        icon: "plus.circle.fill",
                        variant: .tertiary,
                        size: .medium,
                        isFullWidth: true
                    ) {
                        viewModel.isShowingRecipientsPicker = true
                    }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Kết thúc kiểm tra", style: .headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Preview PDF Button
                LMSButton(
                    "Xem PDF",
                    icon: "doc.text.magnifyingglass",
                    variant: .tertiary,
                    size: .large,
                    isFullWidth: true,
                    isDisabled: viewModel.isGeneratingPDF
                ) {
                    Task {
                        await viewModel.generateAndPreviewPDF()
                    }
                }
                
                // Send Email Button
                LMSButton(
                    "Gửi Email",
                    icon: "paperplane.fill",
                    variant: .primary,
                    size: .large,
                    isFullWidth: true,
                    isDisabled: viewModel.isGeneratingPDF
                ) {
                    Task {
                        await viewModel.generateAndSendPDF()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var savePhotosSection: some View {
        LMSButton(
            "Lưu vào tập ảnh (\(viewModel.totalPhotosCount))",
            icon: "photo.on.rectangle.angled",
            variant: .secondary,
            size: .medium,
            isFullWidth: true,
            isDisabled: viewModel.isSavingPhotos || viewModel.totalPhotosCount == 0
        ) {
            Task {
                await viewModel.saveAllPhotosToLibrary()
            }
        }
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
                            
                            LMSLabel(recipient.name, style: .body, color: .primary)
                            
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



// MARK: - Preview
#Preview {
    FinalReportView(
        inspection: Inspection.mock(inspectionId: "1", inspectionNumber: "001"),
        capturedPhotos: ["field1": [InspectionImage(image: UIImage(systemName: "photo")!)]]
    )
}
