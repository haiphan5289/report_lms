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
    @Published var isLoading = true
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let storageService: InspectionStorageServiceType
    private let groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase
    private var cancellables = Set<AnyCancellable>()
    private var isCacheReady = false

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
                        self?.isCacheReady = true
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

        let inspections = storageService.getAllInspections().filter { $0.status == .plan }
        let sections = groupInspectionsByWeekUseCase.execute(inspections)
        weeklyInspections = sections

        // Keep loading until Firestore cache is ready
        if isCacheReady {
            isLoading = false
        }
    }

    func visibleInspections(for section: WeekSection) -> [Inspection] {
        section.inspections
    }

    func addNewInspection(_ inspection: Inspection) async {
        // Reload from cache (inspection was already saved by CreateInspectionViewModel)
        await loadInspections()
    }
}
