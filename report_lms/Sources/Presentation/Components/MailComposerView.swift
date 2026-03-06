//
//  MailComposerView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import SwiftUI
import MessageUI
import OSLog

/// SwiftUI wrapper for MFMailComposeViewController
struct MailComposerView: UIViewControllerRepresentable {
    // MARK: - Properties
    let pdfData: Data
    let inspectionNumber: String
    let recipientEmail: String?
    let onComplete: ((MFMailComposeResult) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger(subsystem: "com.reportlms.mail", category: "composer")
    
    // MARK: - Initialization
    init(
        pdfData: Data,
        inspectionNumber: String,
        recipientEmail: String? = nil,
        onComplete: ((MFMailComposeResult) -> Void)? = nil
    ) {
        self.pdfData = pdfData
        self.inspectionNumber = inspectionNumber
        self.recipientEmail = recipientEmail
        self.onComplete = onComplete
    }
    
    // MARK: - UIViewControllerRepresentable
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Set email subject
        let subject = "Báo cáo kiểm tra #\(inspectionNumber)"
        composer.setSubject(subject)
        
        // Set recipient if provided
        if let recipientEmail = recipientEmail {
            composer.setToRecipients([recipientEmail])
        }
        
        // Set email body
        let body = """
        Kính gửi,
        
        Đính kèm là báo cáo kiểm tra #\(inspectionNumber) chi tiết.
        
        Vui lòng xem tài liệu đính kèm để biết thêm thông tin.
        
        Trân trọng,
        """
        composer.setMessageBody(body, isHTML: false)
        
        // Attach PDF
        let fileName = "Bao_cao_kiem_tra_\(inspectionNumber).pdf"
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: fileName)
        
        logger.log("Mail composer initialized with PDF attachment: \(fileName), size: \(pdfData.count) bytes")
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, logger: logger, onComplete: onComplete)
    }
    
    // MARK: - Coordinator
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        let logger: Logger
        let onComplete: ((MFMailComposeResult) -> Void)?
        
        init(dismiss: DismissAction, logger: Logger, onComplete: ((MFMailComposeResult) -> Void)?) {
            self.dismiss = dismiss
            self.logger = logger
            self.onComplete = onComplete
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController,
                                  didFinishWith result: MFMailComposeResult,
                                  error: Error?) {
            if let error = error {
                logger.error("Mail composer error: \(error.localizedDescription)")
            }
            
            switch result {
            case .cancelled:
                logger.log("User cancelled email")
            case .saved:
                logger.log("Email saved as draft")
            case .sent:
                logger.log("Email sent successfully")
            case .failed:
                logger.error("Email failed to send")
            @unknown default:
                logger.warning("Unknown mail compose result")
            }
            
            onComplete?(result)
            dismiss()
        }
    }
}

// MARK: - Mail Availability Check
extension MailComposerView {
    /// Check if mail services are available on the device
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
}

// MARK: - Preview
#Preview("Mail Composer") {
    struct PreviewWrapper: View {
        @State private var showMailComposer = false
        
        var body: some View {
            VStack {
                Button("Open Mail Composer") {
                    showMailComposer = true
                }
                .sheet(isPresented: $showMailComposer) {
                    if MailComposerView.canSendMail {
                        MailComposerView(
                            pdfData: Data(),
                            inspectionNumber: "001"
                        )
                    } else {
                        Text("Mail services are not available")
                            .padding()
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
}
