//
//  InspectionValidationViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import Foundation
import SwiftUI


@MainActor
final class InspectionValidationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var status: ValidationStatus = .pending
    @Published var comments: String = ""
    @Published var images: [InspectionImage] = []
    @Published var showCamera: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showReorderMode: Bool = false
    @Published var isDirty: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    
    // MARK: - Private Properties
    private var imageIndexToDelete: Int?
    private let fieldId: String
    private let inspectionId: String?
    let fieldLabel: String
    private var onSave: ((FieldValidation) -> Void)?
    private var onUploadComplete: (() -> Void)?
    private let initialStatus: ValidationStatus
    private let initialComments: String
    private let initialImagesCount: Int
    private let storageService: InspectionStorageServiceType?
    private let uploadUseCase: UploadInspectionMediaUseCase?

    // MARK: - Initialization
    init(
        fieldId: String,
        fieldLabel: String,
        initialImages: [InspectionImage],
        initialStatus: ValidationStatus = .pending,
        initialComments: String = "",
        inspectionId: String? = nil,
        storageService: InspectionStorageServiceType? = nil,
        onSave: ((FieldValidation) -> Void)? = nil,
        onUploadComplete: (() -> Void)? = nil
    ) {
        self.fieldId = fieldId
        self.fieldLabel = fieldLabel
        self.images = initialImages
        self.initialStatus = initialStatus
        self.initialComments = initialComments
        self.initialImagesCount = initialImages.count
        self.status = initialStatus
        self.comments = initialComments
        self.inspectionId = inspectionId
        self.storageService = storageService ?? Container.shared.resolve(InspectionStorageServiceType.self)
        self.uploadUseCase = Container.shared.resolve(UploadInspectionMediaUseCase.self)
        self.onSave = onSave
        self.onUploadComplete = onUploadComplete
    }
    
    // MARK: - Computed Properties
    var hasImages: Bool {
        !images.isEmpty
    }
    
    var canSave: Bool {
        !images.isEmpty
    }
    
    // MARK: - Public Methods
    
    /// Append new images from camera
    func appendImages(_ newImages: [UIImage]) {
        let newInspectionImages = newImages.map { InspectionImage(image: $0) }
        images.append(contentsOf: newInspectionImages)
        updateDirtyState()
    }
    
    /// Show confirmation before removing image
    func requestDeleteImage(at index: Int) {
        imageIndexToDelete = index
        showDeleteConfirmation = true
    }
    
    /// Remove image at specific index (after confirmation)
    func confirmDeleteImage() {
        guard let index = imageIndexToDelete,
              images.indices.contains(index) else { return }
        images.remove(at: index)
        updateDirtyState()
        imageIndexToDelete = nil
    }
    
    /// Cancel image deletion
    func cancelDeleteImage() {
        imageIndexToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Move image from source to destination
    func moveImage(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
        updateDirtyState()
    }
    
    /// Toggle reorder mode
    func toggleReorderMode() {
        showReorderMode.toggle()
    }
    
    /// Open camera to capture more photos
    func openCamera() {
        showCamera = true
    }
    
    /// Save validation with specified status
    func saveValidation(status: ValidationStatus) {
        self.status = status

        let validation = FieldValidation(
            id: fieldId,
            status: status,
            comments: comments,
            images: images,
            lastUpdated: Date()
        )

        // Save draft locally
        saveDraft(validation)

        // Upload images to Firebase Storage, then update inspection status and photo URLs
        let imagesToUpload = images
        Task {
            await uploadPhotosAndUpdateField(fieldId: fieldId, images: imagesToUpload)
            await updateInspectionStatus()
        }

        // Call save callback
        onSave?(validation)

        // Reset dirty state
        isDirty = false
    }
    
    /// Update comments
    func updateComments(_ newComments: String) {
        comments = newComments
        updateDirtyState()
    }
    
    // MARK: - Private Methods
    
    private func uploadPhotosAndUpdateField(fieldId: String, images: [InspectionImage]) async {
        guard let inspectionId = inspectionId,
              let storageService = storageService,
              let uploadUseCase = uploadUseCase else { return }

        var uploadedURLs: [String] = []
        for inspectionImage in images {
            guard let imageData = inspectionImage.image.jpegData(compressionQuality: 0.8) else { continue }
            do {
                let url = try await uploadUseCase.execute(imageData: imageData, inspectionId: inspectionId)
                uploadedURLs.append(url)
            } catch {
                print("🔴 [InspectionValidationViewModel] Failed to upload image: \(error)")
            }
        }

        guard !uploadedURLs.isEmpty else { return }

        guard var inspection = storageService.getInspection(by: inspectionId) else { return }

        for sectionIndex in inspection.sections.indices {
            if let fieldIndex = inspection.sections[sectionIndex].fields.firstIndex(where: { $0.id == fieldId }) {
                inspection.sections[sectionIndex].fields[fieldIndex].imageURLs = uploadedURLs
                inspection.sections[sectionIndex].fields[fieldIndex].photoURL = uploadedURLs.first
                break
            }
        }

        do {
            try await storageService.updateInspection(inspection)
            print("✅ [InspectionValidationViewModel] Photo URLs saved to Firestore for field \(fieldId)")
            onUploadComplete?()
        } catch {
            print("🔴 [InspectionValidationViewModel] Failed to save photo URLs: \(error)")
        }
    }

    private func updateInspectionStatus() async {
        guard let inspectionId = inspectionId,
              let storageService = storageService,
              var inspection = storageService.getInspection(by: inspectionId) else {
            return
        }
        
        // Update status to inProgress
        inspection.status = .inProgress
        
        do {
            try await storageService.updateInspection(inspection)
        } catch {
            print("Failed to update inspection status: \(error)")
        }
    }
    
    private func updateDirtyState() {
        isDirty = status != initialStatus ||
                  comments != initialComments ||
                  images.count != initialImagesCount
    }
    
    private func saveDraft(_ validation: FieldValidation) {
        // Save to UserDefaults for draft persistence
        // Future: Migrate to CoreData or local database
        let key = "draft_validation_\(fieldId)"
        
        // Only save count and meta for now; image/description persistence is not implemented here
        let draftData = [
            "status": validation.status.rawValue,
            "comments": validation.comments,
            "imageCount": validation.images.count,
            "lastUpdated": validation.lastUpdated.timeIntervalSince1970
        ] as [String : Any]
        if let jsonData = try? JSONSerialization.data(withJSONObject: draftData) {
            UserDefaults.standard.set(jsonData, forKey: key)
        }
    }
    
    func loadDraft() {
        let key = "draft_validation_\(fieldId)"
        guard let jsonData = UserDefaults.standard.data(forKey: key),
              let draftData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        if let statusString = draftData["status"] as? String,
           let status = ValidationStatus(rawValue: statusString) {
            self.status = status
        }
        
        if let comments = draftData["comments"] as? String {
            self.comments = comments
        }
    }
}

// MARK: - Preview Helpers
extension InspectionValidationViewModel {
    static func preview() -> InspectionValidationViewModel {
        InspectionValidationViewModel(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                InspectionImage(image: UIImage(systemName: "photo")!),
                InspectionImage(image: UIImage(systemName: "photo.fill")!),
                InspectionImage(image: UIImage(systemName: "photo.circle")!),
                InspectionImage(image: UIImage(systemName: "photo.circle.fill")!)
            ]
        )
    }
    
    static func previewEmpty() -> InspectionValidationViewModel {
        InspectionValidationViewModel(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: []
        )
    }
}
