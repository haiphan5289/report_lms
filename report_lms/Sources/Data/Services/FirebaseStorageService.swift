//
//  FirebaseStorageService.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation
import FirebaseStorage

actor FirebaseStorageService {
    private let storage = Storage.storage()

    func uploadImage(_ imageData: Data, path: String) async throws -> String {
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        let metadata = StorageMetadata()
        metadata.contentType = imageData.imageContentType
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }

    func uploadImageWithProgress(
        _ imageData: Data,
        path: String,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> String {
        let imageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = imageData.imageContentType

        // Holds the Firebase StorageUploadTask so the cancellation handler can call .cancel()
        // on it. Without this, cancelling the Swift Task leaves the Firebase upload running
        // as a "zombie" — still holding a URLSession connection. URLSession has a max of 6
        // connections per host, so accumulating zombie uploads starves subsequent slots.
        let holder = UploadTaskHolder()

        // Race the upload against a 90-second timeout. The timeout task cancels the
        // parent task (via `Task.cancel()`) which triggers `onCancel` → `holder.task?.cancel()`.
        // Firebase calls its completion handler with a cancellation error → continuation
        // resumes → URLSession connection is freed immediately (no zombie).
        return try await withThrowingTaskGroup(of: String.self) { tg in
            tg.addTask {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        let uploadTask = imageRef.putData(imageData, metadata: metadata) { _, error in
                            if let error {
                                continuation.resume(throwing: error)
                                return
                            }
                            Task {
                                do {
                                    let url = try await imageRef.downloadURL()
                                    continuation.resume(returning: url.absoluteString)
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                        uploadTask.observe(.progress) { snapshot in
                            onProgress(snapshot.progress?.fractionCompleted ?? 0)
                        }
                        holder.task = uploadTask
                    }
                } onCancel: {
                    holder.task?.cancel()
                }
            }
            tg.addTask {
                try await Task.sleep(nanoseconds: 90_000_000_000)
                throw URLError(.timedOut)
            }
            let result = try await tg.next()!
            tg.cancelAll()
            return result
        }
    }

    /// @unchecked Sendable wrapper so StorageUploadTask can be shared between the
    /// withCheckedThrowingContinuation setup block and the withTaskCancellationHandler onCancel block.
    private final class UploadTaskHolder: @unchecked Sendable {
        var task: StorageUploadTask?
    }

    func downloadImage(from url: String) async throws -> Data {
        let storageRef = storage.reference(forURL: url)
        return try await storageRef.data(maxSize: 10 * 1024 * 1024) // 10MB limit
    }

    func downloadData(fromPath path: String) async throws -> Data {
        let ref = storage.reference().child(path)
        return try await ref.data(maxSize: 20 * 1024 * 1024) // 20MB for PDF reports
    }

    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        try await imageRef.delete()
    }

    func deleteImage(fromURL url: String) async throws {
        let imageRef = storage.reference(forURL: url)
        try await imageRef.delete()
    }

    /// Deletes every file under a Storage path prefix (e.g. "inspections/{id}").
    /// Uses listAll() so orphaned files — whose URLs were never saved to Firestore — are also removed.
    /// Individual item failures are logged but do not stop the loop.
    func deleteFolder(path: String) async {
        let ref = storage.reference().child(path)
        guard let result = try? await ref.listAll() else { return }
        for item in result.items {
            do {
                try await item.delete()
            } catch {
                // Log but continue — delete as many as possible
                print("[FirebaseStorage] Failed to delete \(item.fullPath): \(error.localizedDescription)")
            }
        }
        // Recurse into sub-folders (fieldId-level folders if the path structure changes)
        for prefix in result.prefixes {
            await deleteFolder(path: prefix.fullPath)
        }
    }
}
