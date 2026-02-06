//
//  UploadInspectionMediaUseCase.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

final class UploadInspectionMediaUseCase {
    private let storageRepository: StorageRepositoryType

    init(storageRepository: StorageRepositoryType) {
        self.storageRepository = storageRepository
    }

    func execute(imageData: Data, inspectionId: String) async throws -> String {
        let path = "inspections/\(inspectionId)/\(UUID().uuidString).jpg"
        return try await storageRepository.uploadImage(imageData, path: path)
    }
}
