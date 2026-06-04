//
//  ReportDeliveryQueueService.swift
//  report_lms
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

enum ReportDeliveryStatus: String {
    case queued
    case processing
    case sent
    case failed
}

final class ReportDeliveryQueueService {
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.reportlms.services", category: "delivery-queue")

    static let collectionName = "report_delivery_queue"

    struct TaskPayload {
        let inspectionId: String
        let inspectionNumber: String
        let recipientEmails: [String]
        let location: String
    }

    /// Writes a delivery task document to Firestore. Returns the new document ID.
    func enqueue(_ payload: TaskPayload) async throws -> String {
        let document: [String: Any] = [
            "inspectionId": payload.inspectionId,
            "inspectionNumber": payload.inspectionNumber,
            "recipientEmails": payload.recipientEmails,
            "location": payload.location,
            "status": ReportDeliveryStatus.queued.rawValue,
            "requestedAt": Timestamp(),
            "requestedBy": Auth.auth().currentUser?.email ?? "unknown"
        ]

        let ref = try await db.collection(Self.collectionName).addDocument(data: document)
        logger.log("Delivery task queued: \(ref.documentID) for #\(payload.inspectionNumber)")
        return ref.documentID
    }

    /// Streams status updates for a queued task. Finishes when status is `sent` or `failed`.
    func statusStream(taskId: String) -> AsyncStream<ReportDeliveryStatus> {
        AsyncStream { continuation in
            let listener = self.db
                .collection(Self.collectionName)
                .document(taskId)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        self?.logger.error("Status listener error: \(error.localizedDescription)")
                        continuation.yield(.failed)
                        continuation.finish()
                        return
                    }
                    let raw = snapshot?.data()?["status"] as? String ?? ""
                    let status = ReportDeliveryStatus(rawValue: raw) ?? .queued
                    continuation.yield(status)
                    if status == .sent || status == .failed {
                        continuation.finish()
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
