//
//  PlanLMSHomeViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import Foundation
import Combine

@MainActor
final class PlanLMSHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var weeklyInspections: [WeekSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let storageService: InspectionStorageServiceType
    private let groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    nonisolated init(
        storageService: InspectionStorageServiceType,
        groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase
    ) {
        self.storageService = storageService
        self.groupInspectionsByWeekUseCase = groupInspectionsByWeekUseCase
        
        // Subscribe to cache loaded notification
        Task { @MainActor in
            NotificationCenter.default.publisher(for: .inspectionCacheDidLoad)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.loadInspections()
                    }
                }
                .store(in: &self.cancellables)
        }
    }

    // MARK: - Public Methods
    func loadInspections() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Load from in-memory cache (already loaded on app launch)
        let inspections = storageService.getAllInspections()
        let sections = groupInspectionsByWeekUseCase.execute(inspections)
        weeklyInspections = sections
    }

    func visibleInspections(for section: WeekSection) -> [Inspection] {
        section.inspections
    }

    func addNewInspection(_ inspection: Inspection) async {
        // Reload from cache (inspection was already saved by CreateInspectionViewModel)
        await loadInspections()
    }
}
