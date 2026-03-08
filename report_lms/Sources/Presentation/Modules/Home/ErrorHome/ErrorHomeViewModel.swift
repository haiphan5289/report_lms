//
//  ErrorHomeViewModel.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI
import Combine

// MARK: - ErrorHomeViewModel

@MainActor
final class ErrorHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errorInspections: [Inspection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let storageService: InspectionStorageServiceType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(storageService: InspectionStorageServiceType? = nil) {
        self.storageService = storageService ?? Container.shared.resolve(InspectionStorageServiceType.self)!
        
        // Subscribe to cache loaded notification
        NotificationCenter.default.publisher(for: .inspectionCacheDidLoad)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadErrorInspections()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    func loadErrorInspections() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }

        // Load inspections with error or inProgress status
        let allInspections = storageService.getAllInspections()
        errorInspections = allInspections.filter { 
            $0.status == .error || $0.status == .inProgress 
        }
    }
}
