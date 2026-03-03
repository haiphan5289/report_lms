//
//  InspectionDetailContentViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/3/26.
//

import Foundation
import SwiftUI

@MainActor
final class InspectionDetailContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var expandedSections: Set<String> = []
    
    // MARK: - Private Properties
    private let onPhotoPickerOpen: (String) -> Void
    private weak var parentViewModel: InspectionDetailViewModel?
    
    // MARK: - Computed Properties
    var inspectionDetail: InspectionDetail? {
        parentViewModel?.inspectionDetail
    }
    
    var capturedPhotos: [String: [UIImage]] {
        parentViewModel?.capturedPhotos ?? [:]
    }
    
    // Statistics
    var totalFields: Int {
        inspectionDetail?.sections.reduce(0) { $0 + $1.fields.count } ?? 0
    }
    
    var fieldsWithPhotos: Int {
        capturedPhotos.filter { !$0.value.isEmpty }.count
    }
    
    // MARK: - Initialization
    init(parentViewModel: InspectionDetailViewModel, onPhotoPickerOpen: @escaping (String) -> Void) {
        self.parentViewModel = parentViewModel
        self.onPhotoPickerOpen = onPhotoPickerOpen
    }
    
    // MARK: - Public Methods
    
    /// Toggle section expansion state
    func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }
    
    /// Check if section is expanded
    func isExpanded(_ sectionId: String) -> Bool {
        expandedSections.contains(sectionId)
    }
    
    /// Check if field has captured photos
    func hasPhoto(for fieldId: String) -> Bool {
        !(capturedPhotos[fieldId]?.isEmpty ?? true)
    }
    
    /// Get captured images for a field
    func getImages(for fieldId: String) -> [UIImage] {
        capturedPhotos[fieldId] ?? []
    }
    
    /// Open photo picker for a field
    func openPhotoPicker(for fieldId: String) {
        onPhotoPickerOpen(fieldId)
    }
    
    /// Auto-expand first section when data loads
    func autoExpandFirstSection() {
        if let firstSection = inspectionDetail?.sections.first {
            expandedSections.insert(firstSection.id)
        }
    }
}

// MARK: - Preview Helpers
extension InspectionDetailContentViewModel {
    static func preview() -> InspectionDetailContentViewModel {
        let parentViewModel = InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        return InspectionDetailContentViewModel(
            parentViewModel: parentViewModel,
            onPhotoPickerOpen: { _ in }
        )
    }
}
