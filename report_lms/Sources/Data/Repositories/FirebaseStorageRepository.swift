//
//  FirebaseStorageRepository.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

final class FirebaseStorageRepository: StorageRepositoryType {
    private let service: FirebaseStorageService
    
    init(service: FirebaseStorageService) {
        self.service = service
    }
    
    func uploadImage(_ imageData: Data, path: String) async throws -> String {
        try await service.uploadImage(imageData, path: path)
    }
    
    func downloadImage(from url: String) async throws -> Data {
        try await service.downloadImage(from: url)
    }
    
    func deleteImage(at path: String) async throws {
        try await service.deleteImage(at: path)
    }
}