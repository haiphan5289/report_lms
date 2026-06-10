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
        return try await withCheckedThrowingContinuation { continuation in
            let task = imageRef.putData(imageData, metadata: metadata) { _, error in
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
            task.observe(.progress) { snapshot in
                onProgress(snapshot.progress?.fractionCompleted ?? 0)
            }
        }
    }

    func downloadImage(from url: String) async throws -> Data {
        let storageRef = storage.reference(forURL: url)
        return try await storageRef.data(maxSize: 10 * 1024 * 1024) // 10MB limit
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
}
