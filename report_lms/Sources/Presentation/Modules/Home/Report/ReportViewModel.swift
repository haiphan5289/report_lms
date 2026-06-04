//
//  ReportViewModel.swift
//  report_lms
//

import Foundation
import Combine

@MainActor
final class ReportViewModel: ObservableObject {
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

        Task { @MainActor in
            for name in [Notification.Name.inspectionCacheDidLoad, .inspectionDidUpdate] {
                NotificationCenter.default.publisher(for: name)
                    .sink { [weak self] _ in
                        Task { @MainActor in
                            await self?.loadInspections()
                        }
                    }
                    .store(in: &self.cancellables)
            }
        }
    }

    // MARK: - Public Methods
    func loadInspections() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let completed = storageService.getAllInspections().filter { $0.status == .completed }
        weeklyInspections = groupInspectionsByWeekUseCase.execute(completed)
    }
}
