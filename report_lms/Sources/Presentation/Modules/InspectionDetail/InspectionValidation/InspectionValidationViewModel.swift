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
    @Published var images: [UIImage] = []
    @Published var showCamera: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showReorderMode: Bool = false
    @Published var isDirty: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    
    // MARK: - Private Properties
    private var imageIndexToDelete: Int?
    private let fieldId: String
    let fieldLabel: String
    private var onSave: ((FieldValidation) -> Void)?
    private let initialStatus: ValidationStatus
    private let initialComments: String
    private let initialImagesCount: Int
    
    // MARK: - Initialization
    init(
        fieldId: String,
        fieldLabel: String,
        initialImages: [UIImage],
        initialStatus: ValidationStatus = .pending,
        initialComments: String = "",
        onSave: ((FieldValidation) -> Void)? = nil
    ) {
        self.fieldId = fieldId
        self.fieldLabel = fieldLabel
        self.images = initialImages
        self.initialStatus = initialStatus
        self.initialComments = initialComments
        self.initialImagesCount = initialImages.count
        self.status = initialStatus
        self.comments = initialComments
        self.onSave = onSave
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
        images.append(contentsOf: newImages)
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
    
    private func updateDirtyState() {
        isDirty = status != initialStatus ||
                  comments != initialComments ||
                  images.count != initialImagesCount
    }
    
    private func saveDraft(_ validation: FieldValidation) {
        // Save to UserDefaults for draft persistence
        // Future: Migrate to CoreData or local database
        let key = "draft_validation_\(fieldId)"
        
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
                UIImage(systemName: "photo")!,
                UIImage(systemName: "photo.fill")!,
                UIImage(systemName: "photo.circle")!,
                UIImage(systemName: "photo.circle.fill")!
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
