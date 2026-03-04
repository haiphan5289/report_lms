//
//  InspectionDetailContentViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/3/26.
//

import Foundation
import SwiftUI
import OSLog

@MainActor
final class InspectionDetailContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var expandedSections: Set<String> = []
    
    // PDF Generation Properties
    @Published var isGeneratingPDF = false
    @Published var isShowingMailComposer = false
    @Published var isShowingPDFPreview = false
    @Published var pdfData: Data?
    @Published var pdfError: String?
    @Published var showMailUnavailableAlert = false
    
    // MARK: - Private Properties
    private let onPhotoPickerOpen: (String) -> Void
    private weak var parentViewModel: InspectionDetailViewModel?
    private let generatePDFUseCase: GenerateHTMLPDFReportUseCase
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "inspection")
    
    // MARK: - Computed Properties
    var inspectionDetail: InspectionDetail? {
        parentViewModel?.inspectionDetail
    }
    
    var capturedPhotos: [String: [UIImage]] {
        parentViewModel?.capturedPhotos ?? [:]
    }
    
    // Statistics
    var totalFields: Int {
        inspectionDetail?.sections.reduce(0) { $0 + $1.fields.count } ?? 0
    }
    
    var fieldsWithPhotos: Int {
        capturedPhotos.filter { !$0.value.isEmpty }.count
    }
    
    // MARK: - Initialization
    init(
        parentViewModel: InspectionDetailViewModel,
        onPhotoPickerOpen: @escaping (String) -> Void,
        generatePDFUseCase: GenerateHTMLPDFReportUseCase? = nil
    ) {
        self.parentViewModel = parentViewModel
        self.onPhotoPickerOpen = onPhotoPickerOpen
        
        if let useCase = generatePDFUseCase {
            self.generatePDFUseCase = useCase
        } else {
            guard let resolvedUseCase = Container.shared.resolve(GenerateHTMLPDFReportUseCase.self) else {
                fatalError("GenerateHTMLPDFReportUseCase must be registered in DI container")
            }
            self.generatePDFUseCase = resolvedUseCase
        }
    }
    
    // MARK: - Public Methods
    
    /// Toggle section expansion state
    func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }
    
    /// Check if section is expanded
    func isExpanded(_ sectionId: String) -> Bool {
        expandedSections.contains(sectionId)
    }
    
    /// Check if field has captured photos
    func hasPhoto(for fieldId: String) -> Bool {
        !(capturedPhotos[fieldId]?.isEmpty ?? true)
    }
    
    /// Get captured images for a field
    func getImages(for fieldId: String) -> [UIImage] {
        capturedPhotos[fieldId] ?? []
    }
    
    /// Open photo picker for a field
    func openPhotoPicker(for fieldId: String) {
        onPhotoPickerOpen(fieldId)
    }
    
    /// Auto-expand first section when data loads
    
    // MARK: - PDF Generation
    
    /// Generate PDF and show preview
    func generateAndPreviewPDF() async {
        guard let detail = inspectionDetail else {
            logger.error("Cannot generate PDF: No inspection detail available")
            pdfError = "Không có dữ liệu kiểm tra"
            return
        }
        
        isGeneratingPDF = true
        pdfError = nil
        pdfData = nil
        
        logger.log("Starting PDF generation for inspection #\(detail.inspectionNumber)")
        
        do {
            let data = try await generatePDFUseCase.execute(
                detail: detail,
                images: capturedPhotos
            )
            
            pdfData = data
            isShowingPDFPreview = true
            
            logger.log("PDF generated successfully, size: \(data.count) bytes")
        } catch {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            pdfError = "Không thể tạo PDF: \(error.localizedDescription)"
        }
        
        isGeneratingPDF = false
    }
    
    /// Generate PDF and prepare for email sending
    func generateAndSendPDF() async {
        guard let detail = inspectionDetail else {
            logger.error("Cannot generate PDF: No inspection detail available")
            pdfError = "Không có dữ liệu kiểm tra"
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
        
        logger.log("Starting PDF generation for inspection #\(detail.inspectionNumber)")
        
        do {
            let data = try await generatePDFUseCase.execute(
                detail: detail,
                images: capturedPhotos
            )
            
            pdfData = data
            isShowingMailComposer = true
            
            logger.log("PDF generated successfully, opening mail composer")
        } catch {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            pdfError = "Không thể tạo PDF: \(error.localizedDescription)"
        }
        
        isGeneratingPDF = false
    }
    
    /// Reset PDF generation state
    func resetPDFState() {
        pdfData = nil
        pdfError = nil
        isShowingMailComposer = false
    }
    func autoExpandFirstSection() {
        if let firstSection = inspectionDetail?.sections.first {
            expandedSections.insert(firstSection.id)
        }
    }
}

// MARK: - Preview Helpers
extension InspectionDetailContentViewModel {
    static func preview() -> InspectionDetailContentViewModel {
        let parentViewModel = InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        return InspectionDetailContentViewModel(
            parentViewModel: parentViewModel,
            onPhotoPickerOpen: { _ in }
        )
    }
}
