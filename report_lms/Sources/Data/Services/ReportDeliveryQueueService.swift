//
//  ReportDeliveryQueueService.swift
//  report_lms
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

// MARK: - ReportDeliveryTask Firestore mapping

extension ReportDeliveryTask {
    init?(from data: [String: Any], id: String) {
        guard let inspectionId       = data["inspectionId"]       as? String,
              let inspectionNumber   = data["inspectionNumber"]   as? String,
              let recipientEmails    = data["recipientEmails"]    as? [String],
              let statusRaw          = data["status"]             as? String
        else { return nil }

        let requestedAt: Date
        if let ts = data["requestedAt"] as? Timestamp {
            requestedAt = ts.dateValue()
        } else {
            requestedAt = Date()
        }

        let sentAt: Date?
        if let ts = data["sentAt"] as? Timestamp { sentAt = ts.dateValue() } else { sentAt = nil }

        self.id               = id
        self.inspectionId     = inspectionId
        self.inspectionNumber = inspectionNumber
        self.recipientEmails  = recipientEmails
        self.location         = data["location"]         as? String ?? ""
        self.requestedBy      = data["requestedBy"]      as? String ?? ""
        self.finalStatus      = data["finalStatus"]      as? String ?? "pending"
        self.summaryComments  = data["summaryComments"]  as? String ?? ""
        self.status           = ReportDeliveryTaskStatus(rawValue: statusRaw) ?? .queued
        self.requestedAt      = requestedAt
        self.sentAt           = sentAt
        self.errorMessage     = data["errorMessage"]     as? String
    }
}

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
        let finalStatus: String
        let summaryComments: String
    }

    /// Writes a delivery task document to Firestore. Returns the new document ID.
    func enqueue(_ payload: TaskPayload) async throws -> String {
        let document: [String: Any] = [
            "inspectionId": payload.inspectionId,
            "inspectionNumber": payload.inspectionNumber,
            "recipientEmails": payload.recipientEmails,
            "location": payload.location,
            "finalStatus": payload.finalStatus,
            "summaryComments": payload.summaryComments,
            "status": ReportDeliveryStatus.queued.rawValue,
            "requestedAt": Timestamp(),
            "requestedBy": Auth.auth().currentUser?.email ?? "unknown"
        ]

        let ref = try await db.collection(Self.collectionName).addDocument(data: document)
        logger.log("Delivery task queued: \(ref.documentID) for #\(payload.inspectionNumber)")
        return ref.documentID
    }

    // MARK: - List & Retry

    /// Real-time listener on the full collection, ordered by requestedAt desc.
    /// The continuation yields a fresh array on every Firestore change.
    func allTasksStream() -> AsyncStream<[ReportDeliveryTask]> {
        AsyncStream { continuation in
            let listener = self.db
                .collection(Self.collectionName)
                .order(by: "requestedAt", descending: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        self?.logger.error("allTasksStream error: \(error.localizedDescription)")
                        continuation.yield([])
                        return
                    }
                    let tasks = snapshot?.documents.compactMap { doc -> ReportDeliveryTask? in
                        ReportDeliveryTask(from: doc.data(), id: doc.documentID)
                    } ?? []
                    continuation.yield(tasks)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Delete

    /// Deletes a single delivery task document from Firestore.
    func deleteTask(taskId: String) async throws {
        try await db
            .collection(Self.collectionName)
            .document(taskId)
            .delete()
        logger.log("Deleted task \(taskId)")
    }

    /// Deletes multiple tasks concurrently. All errors are collected; throws the first if any fail.
    func deleteTasks(taskIds: [String]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for taskId in taskIds {
                group.addTask {
                    try await self.db
                        .collection(Self.collectionName)
                        .document(taskId)
                        .delete()
                }
            }
            try await group.waitForAll()
        }
        logger.log("Deleted \(taskIds.count) tasks")
    }

    /// Updates an existing failed task's status back to `queued` so the Cloud Function re-processes it.
    func retryTask(taskId: String) async throws {
        try await db
            .collection(Self.collectionName)
            .document(taskId)
            .updateData(["status": ReportDeliveryStatus.queued.rawValue])
        logger.log("Retry queued for task \(taskId)")
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
