//
//  PendingUploadRetryService.swift
//  report_lms
//

import Foundation
import UIKit

/// Retries Firebase Storage uploads for images captured in a previous session (e.g. app was killed
/// before upload completed). Called at app launch, after the inspection cache is loaded.
///
/// This runs independently of any ViewModel — no UI tracking (activeUploadCount, sessions).
/// InspectionDetailViewModel still calls retryAllPendingUploads() as a fallback for fields
/// that haven't finished yet when the user navigates to InspectionDetailView.
final class PendingUploadRetryService {
    static let shared = PendingUploadRetryService()
    private init() {}

    func retryAllPendingUploads() {
        guard let uploadUseCase = Container.shared.resolve(UploadInspectionMediaUseCase.self),
              let storageService = Container.shared.resolve(InspectionStorageServiceType.self) else { return }

        let inspectionIds = PendingUploadStore.shared.getAllPendingInspectionIds()
        guard !inspectionIds.isEmpty else { return }

        for inspectionId in inspectionIds {
            let pendingFields = PendingUploadStore.shared.getAllPendingFields(for: inspectionId)
            for (fieldId, paths) in pendingFields {
                Task {
                    await uploadField(
                        inspectionId: inspectionId,
                        fieldId: fieldId,
                        paths: paths,
                        uploadUseCase: uploadUseCase,
                        storageService: storageService
                    )
                }
            }
        }
    }

    private func uploadField(
        inspectionId: String,
        fieldId: String,
        paths: [String],
        uploadUseCase: UploadInspectionMediaUseCase,
        storageService: InspectionStorageServiceType
    ) async {
        // Read full-resolution JPEG directly from disk, bypassing the RAM cache which stores
        // an 800px thumbnail — upload must always use original quality.
        var loadedImages: [UIImage] = []
        for path in paths {
            let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
                return UIImage(data: data)
            }.value
            guard let img else { continue }
            loadedImages.append(img)
        }
        guard !loadedImages.isEmpty else {
            PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
            return
        }

        // Preserve any remote URLs already saved (prior partial upload)
        let existingRemoteURLs: [String]
        if let inspection = storageService.getInspection(by: inspectionId),
           let field = inspection.sections.flatMap({ $0.fields }).first(where: { $0.id == fieldId }) {
            existingRemoteURLs = field.imageURLs
        } else {
            existingRemoteURLs = []
        }

        var newlyUploadedURLs: [String] = []
        for image in loadedImages {
            let compressedData = await Task.detached(priority: .utility) {
                image.prepareForUpload()
            }.value
            guard let data = compressedData else { continue }
            do {
                let url = try await uploadUseCase.execute(imageData: data, inspectionId: inspectionId)
                newlyUploadedURLs.append(url)
            } catch {
                // Partial failure — leave in PendingUploadStore for next retry
                return
            }
        }

        let allURLs = existingRemoteURLs + newlyUploadedURLs
        guard !allURLs.isEmpty else { return }

        do {
            try await storageService.updateFieldImageURLs(
                inspectionId: inspectionId,
                fieldId: fieldId,
                imageURLs: allURLs
            )
            PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
            CacheDebugLogger.shared.log(.uploadSuccess(fieldId: fieldId))
        } catch {
            // Leave in PendingUploadStore — InspectionDetailViewModel will retry on navigation
        }
    }
}
