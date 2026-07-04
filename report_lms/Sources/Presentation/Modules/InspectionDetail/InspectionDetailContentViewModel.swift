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
    private let onTextTap: (String) -> Void
    private let onCameraTap: (String) -> Void
    private weak var parentViewModel: InspectionDetailViewModel?

    // MARK: - Computed Properties
    var inspection: Inspection? {
        parentViewModel?.inspection
    }
    
    var capturedPhotos: [String: [InspectionImage]] {
        parentViewModel?.capturedPhotos ?? [:]
    }

    var sortedSections: [InspectionSection] {
        inspection?.sections.sorted(by: { $0.order < $1.order }) ?? []
    }
    
    // Statistics
    var totalFields: Int {
        inspection?.sections.reduce(0) { $0 + $1.fields.count } ?? 0
    }
    
    var fieldsWithPhotos: Int {
        capturedPhotos.filter { !$0.value.isEmpty }.count
    }

    func completedCount(for section: InspectionSection) -> Int {
        section.fields.filter { !(capturedPhotos[$0.id]?.isEmpty ?? true) }.count
    }
    
    // MARK: - Initialization
    init(
        parentViewModel: InspectionDetailViewModel,
        onTextTap: @escaping (String) -> Void,
        onCameraTap: @escaping (String) -> Void
    ) {
        self.parentViewModel = parentViewModel
        self.onTextTap = onTextTap
        self.onCameraTap = onCameraTap
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
    func getImages(for fieldId: String) -> [InspectionImage] {
        capturedPhotos[fieldId] ?? []
    }
    
    /// Open validation view for a field (text tap)
    func openValidationView(for fieldId: String) {
        onTextTap(fieldId)
    }
    
    /// Open camera for a field (icon tap)
    func openCamera(for fieldId: String) {
        onCameraTap(fieldId)
    }
    
    /// Auto-expand first section when data loads
    func autoExpandFirstSection() {
        if let firstSection = inspection?.sections.first {
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
            onTextTap: { _ in },
            onCameraTap: { _ in }
        )
    }
}
