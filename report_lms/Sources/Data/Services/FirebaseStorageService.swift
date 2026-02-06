//
//  FirebaseStorageService.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation
import FirebaseStorage

final class FirebaseStorageService {
    private let storage = Storage.storage()
    
    func uploadImage(_ imageData: Data, path: String) async throws -> String {
        let storageRef = storage.reference()
        let imageRef = storageRef.child(path)
        
        _ = try await imageRef.putDataAsync(imageData, metadata: nil)
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
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
}