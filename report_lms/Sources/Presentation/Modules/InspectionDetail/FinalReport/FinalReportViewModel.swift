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
// Import InspectionImage
import UIKit

@MainActor
final class FinalReportViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedStatus: FinalReportStatus = .pending
    @Published var summaryComments: String = ""
    @Published var location: String = ""
    @Published var recipientEmail: String = ""
    @Published var selectedRecipients: [FinalReportRecipient] = []
    @Published var isShowingRecipientsPicker = false
    @Published var isNotificationSectionExpanded = false
    
    // PDF Generation
    @Published var isGeneratingPDF = false
    @Published var pdfGenerationProgress: Double = 0.0
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
    
    // MARK: - Queue Delivery
    @Published var isSendingToServer = false
    @Published var showEmailQueuedAlert = false

    // MARK: - Private Properties
    let inspection: Inspection?
    private let capturedPhotos: [String: [InspectionImage]]
    private let generatePDFUseCase: GenerateHTMLPDFReportUseCase
    private let storageService: InspectionStorageServiceType
    private let queueDeliveryUseCase: QueueReportDeliveryUseCase
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "finalreport")
    
    // MARK: - Computed Properties
    var recipientsCount: Int {
        selectedRecipients.count
    }
    
    var availableRecipients: [FinalReportRecipient] {
        FinalReportRecipient.mockRecipients
    }
    
    var allPhotos: [UIImage] {
        // Remote images are already on Firebase — only save locally captured ones to the library.
        capturedPhotos.values.flatMap { $0.compactMap { $0.isRemote ? nil : $0.image } }
    }
    
    var totalPhotosCount: Int {
        allPhotos.count
    }
    
    // MARK: - Initialization
    init(
        inspection: Inspection?,
        capturedPhotos: [String: [InspectionImage]],
        generatePDFUseCase: GenerateHTMLPDFReportUseCase? = nil,
        storageService: InspectionStorageServiceType? = nil,
        queueDeliveryUseCase: QueueReportDeliveryUseCase? = nil
    ) {
        self.inspection = inspection
        self.capturedPhotos = capturedPhotos
        self.recipientEmail = "freelancerios0502@gmail.com"

        if let useCase = generatePDFUseCase {
            self.generatePDFUseCase = useCase
        } else {
            guard let resolvedUseCase = Container.shared.resolve(GenerateHTMLPDFReportUseCase.self) else {
                fatalError("GenerateHTMLPDFReportUseCase must be registered in DI container")
            }
            self.generatePDFUseCase = resolvedUseCase
        }

        if let service = storageService {
            self.storageService = service
        } else {
            guard let resolved = Container.shared.resolve(InspectionStorageServiceType.self) else {
                fatalError("InspectionStorageServiceType must be registered in DI container")
            }
            self.storageService = resolved
        }

        if let queueUseCase = queueDeliveryUseCase {
            self.queueDeliveryUseCase = queueUseCase
        } else {
            guard let resolved = Container.shared.resolve(QueueReportDeliveryUseCase.self) else {
                fatalError("QueueReportDeliveryUseCase must be registered in DI container")
            }
            self.queueDeliveryUseCase = resolved
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
        pdfGenerationProgress = 0.0
        pdfError = nil
        pdfData = nil

        logger.log("Starting PDF generation with Builder Pattern for inspection #\(detail.inspectionNumber)")

        do {
            // Stage 1: build request → 30%
            let request = try PDFReportRequestBuilder.withDefaults()
                .with(inspection: detail)
                .with(images: capturedPhotos)
                .with(location: location)
                .with(finalStatus: selectedStatus)
                .with(summaryComments: summaryComments)
                .build()
            pdfGenerationProgress = 0.30

            // Stage 2: fill to 85% while execute runs
            let fillTask = Task {
                var p = 0.30
                while !Task.isCancelled && p < 0.85 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    p = min(p + 0.08, 0.85)
                    pdfGenerationProgress = p
                }
            }

            let data = try await generatePDFUseCase.execute(request: request)
            fillTask.cancel()

            // Stage 3: done → 100%
            pdfGenerationProgress = 1.0
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
        pdfGenerationProgress = 0.0
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
                .with(finalStatus: selectedStatus)
                .with(summaryComments: summaryComments)
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
    
    /// Entry point for sending report — routes to Firebase queue or legacy mail composer.
    func sendReport() async {
        if FeatureFlags.useFirebaseReportDelivery {
            await sendReportViaQueue()
        } else {
            await generateAndSendPDF()
        }
    }

    /// Queues a Firestore delivery task and listens for server-side status updates.
    func sendReportViaQueue() async {
        guard let inspection else {
            errorAlertMessage = "Không có dữ liệu kiểm tra"
            showErrorAlert = true
            return
        }

        isSendingToServer = true
        defer { isSendingToServer = false }

        do {
            var allRecipients = selectedRecipients
            let trimmed = recipientEmail.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                allRecipients.append(FinalReportRecipient(name: trimmed, email: trimmed))
            }

            let taskId = try await queueDeliveryUseCase.execute(
                inspection: inspection,
                recipients: allRecipients,
                location: location,
                finalStatus: selectedStatus,
                summaryComments: summaryComments
            )
            logger.log("Report queued: \(taskId)")
            showEmailQueuedAlert = true
            await markInspectionCompleted()

            for await status in queueDeliveryUseCase.statusStream(taskId: taskId) {
                switch status {
                case .sent:
                    showEmailSuccessAlert = true
                case .failed:
                    errorAlertMessage = "Gửi báo cáo thất bại. Vui lòng thử lại."
                    showErrorAlert = true
                default:
                    break
                }
            }
        } catch {
            logger.error("Queue delivery failed: \(error.localizedDescription)")
            errorAlertMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    /// Marks inspection as completed in Firestore, then triggers navigation to the Report tab.
    private func markInspectionCompleted() async {
        guard var updated = inspection else { return }
        updated.status = .completed
        do {
            try await storageService.updateInspection(updated)
            logger.log("Inspection \(updated.inspectionNumber) marked as completed")
            NotificationCenter.default.post(
                name: .navigateToReportTab,
                object: nil,
                userInfo: ["inspectionId": updated.id]
            )
        } catch {
            logger.error("Failed to mark inspection as completed: \(error.localizedDescription)")
        }
    }

    /// Handle email sent successfully — marks the inspection as completed (legacy mail path).
    func handleEmailSent() async {
        await markInspectionCompleted()
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
        let mockPhotos = [
            "field1": [
                InspectionImage(image: UIImage(systemName: "photo") ?? UIImage(), description: "Sample description")
            ]
        ]
        return FinalReportViewModel(
            inspection: mockDetail,
            capturedPhotos: mockPhotos
        )
    }
}
