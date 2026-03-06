//
//  FinalReportViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import Foundation
import SwiftUI
import Photos
import OSLog

@MainActor
final class FinalReportViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedStatus: FinalReportStatus = .pending
    @Published var summaryComments: String = ""
    @Published var location: String = ""
    @Published var selectedRecipients: [FinalReportRecipient] = []
    @Published var isShowingRecipientsPicker = false
    @Published var isNotificationSectionExpanded = false
    
    // PDF Generation
    @Published var isGeneratingPDF = false
    @Published var isShowingMailComposer = false
    @Published var isShowingPDFPreview = false
    @Published var pdfData: Data?
    @Published var pdfError: String?
    @Published var showMailUnavailableAlert = false
    
    // Photo Saving
    @Published var isSavingPhotos = false
    @Published var showPhotoSaveSuccess = false
    @Published var showPhotoSaveError = false
    @Published var photoSaveErrorMessage: String?
    
    // Success/Error Alerts
    @Published var showEmailSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorAlertMessage: String?
    
    // MARK: - Private Properties
    let inspection: Inspection?
    private let capturedPhotos: [String: [UIImage]]
    private let generatePDFUseCase: GenerateHTMLPDFReportUseCase
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "finalreport")
    
    // MARK: - Computed Properties
    var recipientsCount: Int {
        selectedRecipients.count
    }
    
    var availableRecipients: [FinalReportRecipient] {
        FinalReportRecipient.mockRecipients
    }
    
    var allPhotos: [UIImage] {
        capturedPhotos.values.flatMap { $0 }
    }
    
    var totalPhotosCount: Int {
        allPhotos.count
    }
    
    // MARK: - Initialization
    init(
        inspection: Inspection?,
        capturedPhotos: [String: [UIImage]],
        generatePDFUseCase: GenerateHTMLPDFReportUseCase? = nil
    ) {
        self.inspection = inspection
        self.capturedPhotos = capturedPhotos
        
        if let useCase = generatePDFUseCase {
            self.generatePDFUseCase = useCase
        } else {
            guard let resolvedUseCase = Container.shared.resolve(GenerateHTMLPDFReportUseCase.self) else {
                fatalError("GenerateHTMLPDFReportUseCase must be registered in DI container")
            }
            self.generatePDFUseCase = resolvedUseCase
        }
    }
    
    // MARK: - Recipient Management
    
    func toggleRecipient(_ recipient: FinalReportRecipient) {
        if let index = selectedRecipients.firstIndex(where: { $0.id == recipient.id }) {
            selectedRecipients.remove(at: index)
        } else {
            selectedRecipients.append(recipient)
        }
    }
    
    func isRecipientSelected(_ recipient: FinalReportRecipient) -> Bool {
        selectedRecipients.contains(where: { $0.id == recipient.id })
    }
    
    func toggleNotificationSection() {
        isNotificationSectionExpanded.toggle()
    }
    
    // MARK: - PDF Generation
    
    /// Generate PDF and show preview (Using Builder Pattern)
    func generateAndPreviewPDF() async {
        guard let detail = inspection else {
            logger.error("Cannot generate PDF: No inspection detail available")
            errorAlertMessage = "Không có dữ liệu kiểm tra"
            showErrorAlert = true
            return
        }
        
        isGeneratingPDF = true
        pdfError = nil
        pdfData = nil
        
        logger.log("Starting PDF generation with Builder Pattern for inspection #\(detail.inspectionNumber)")
        
        do {
            // Build request using Builder Pattern
            let request = try PDFReportRequestBuilder.withDefaults()
                .with(inspection: detail)
                .with(images: capturedPhotos)
                .with(location: location)
                .build()
            
            // Execute with request object
            let data = try await generatePDFUseCase.execute(request: request)
            
            pdfData = data
            isShowingPDFPreview = true
            
            logger.log("PDF generated successfully using Builder Pattern, size: \(data.count) bytes")
        } catch let error as PDFReportBuilderError {
            logger.error("Builder validation failed: \(error.localizedDescription)")
            errorAlertMessage = "Lỗi xây dựng PDF: \(error.localizedDescription)"
            showErrorAlert = true
        } catch {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            errorAlertMessage = "Không thể tạo PDF: \(error.localizedDescription)"
            showErrorAlert = true
        }
        
        isGeneratingPDF = false
    }
    
    /// Generate PDF and prepare for email sending (Using Builder Pattern)
    func generateAndSendPDF() async {
        guard let detail = inspection else {
            logger.error("Cannot generate PDF: No inspection detail available")
            errorAlertMessage = "Không có dữ liệu kiểm tra"
            showErrorAlert = true
            return
        }
        
        // Check if mail is available
        guard MailComposerView.canSendMail else {
            logger.warning("Mail services not available")
            showMailUnavailableAlert = true
            return
        }
        
        isGeneratingPDF = true
        pdfError = nil
        pdfData = nil
        
        logger.log("Starting PDF generation for email with Builder Pattern, inspection #\(detail.inspectionNumber)")
        
        do {
            // Build request using Builder Pattern
            let request = try PDFReportRequestBuilder.withDefaults()
                .with(inspection: detail)
                .with(images: capturedPhotos)
                .with(location: location)
                .build()
            
            // Execute with request object
            let data = try await generatePDFUseCase.execute(request: request)
            
            pdfData = data
            isShowingMailComposer = true
            
            logger.log("PDF generated successfully using Builder Pattern, opening mail composer")
        } catch let error as PDFReportBuilderError {
            logger.error("Builder validation failed: \(error.localizedDescription)")
            errorAlertMessage = "Lỗi validation: \(error.localizedDescription)"
            showErrorAlert = true
        } catch {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            errorAlertMessage = "Không thể tạo PDF: \(error.localizedDescription)"
            showErrorAlert = true
        }
        
        isGeneratingPDF = false
    }
    
    /// Handle email sent successfully
    func handleEmailSent() {
        showEmailSuccessAlert = true
    }
    
    /// Reset PDF state
    func resetPDFState() {
        pdfData = nil
        pdfError = nil
        isShowingMailComposer = false
    }
    
    // MARK: - Photo Saving
    
    /// Save all photos to photo library
    func saveAllPhotosToLibrary() async {
        guard !allPhotos.isEmpty else {
            errorAlertMessage = "Không có ảnh để lưu"
            showErrorAlert = true
            return
        }
        
        isSavingPhotos = true
        logger.log("Saving \(self.totalPhotosCount) photos to library")
        
        // Request authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized else {
            logger.error("Photo library access denied")
            photoSaveErrorMessage = "Không có quyền truy cập thư viện ảnh. Vui lòng cấp quyền trong Cài đặt."
            showPhotoSaveError = true
            isSavingPhotos = false
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for image in self.allPhotos {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
            
            logger.log("Successfully saved \(self.totalPhotosCount) photos")
            showPhotoSaveSuccess = true
        } catch {
            logger.error("Failed to save photos: \(error.localizedDescription)")
            photoSaveErrorMessage = "Không thể lưu ảnh: \(error.localizedDescription)"
            showPhotoSaveError = true
        }
        
        isSavingPhotos = false
    }
}

// MARK: - Preview Helpers
extension FinalReportViewModel {
    static func preview() -> FinalReportViewModel {
        let mockDetail = Inspection.mock(inspectionId: "1", inspectionNumber: "001")
        let mockPhotos = ["field1": [UIImage(systemName: "photo")].compactMap { $0 }]
        return FinalReportViewModel(
            inspection: mockDetail,
            capturedPhotos: mockPhotos
        )
    }
}
