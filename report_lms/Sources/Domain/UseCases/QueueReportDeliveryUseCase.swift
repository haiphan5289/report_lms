//
//  QueueReportDeliveryUseCase.swift
//  report_lms
//

import Foundation
import OSLog

enum QueueDeliveryError: LocalizedError {
    case noRecipients

    var errorDescription: String? {
        switch self {
        case .noRecipients:
            return "Vui lòng thêm ít nhất một người nhận có email"
        }
    }
}

final class QueueReportDeliveryUseCase {
    private let queueService: ReportDeliveryQueueService
    private let logger = Logger(subsystem: "com.reportlms.usecases", category: "queue-delivery")

    init(queueService: ReportDeliveryQueueService) {
        self.queueService = queueService
    }

    /// Validates recipients and enqueues a Firestore delivery task.
    /// Returns the task document ID for status listening.
    func execute(
        inspection: Inspection,
        recipients: [FinalReportRecipient],
        location: String,
        finalStatus: FinalReportStatus = .pending,
        summaryComments: String = ""
    ) async throws -> String {
        let emails = recipients.map(\.email).filter { !$0.isEmpty }

        guard !emails.isEmpty else {
            logger.error("Queue delivery failed: no valid recipient emails")
            throw QueueDeliveryError.noRecipients
        }

        let payload = ReportDeliveryQueueService.TaskPayload(
            inspectionId: inspection.id,
            inspectionNumber: inspection.inspectionNumber,
            recipientEmails: emails,
            location: location,
            finalStatus: finalStatus.serverKey,
            summaryComments: summaryComments
        )

        let taskId = try await queueService.enqueue(payload)
        logger.log("Report delivery queued: \(taskId)")
        return taskId
    }

    func statusStream(taskId: String) -> AsyncStream<ReportDeliveryStatus> {
        queueService.statusStream(taskId: taskId)
    }
}
