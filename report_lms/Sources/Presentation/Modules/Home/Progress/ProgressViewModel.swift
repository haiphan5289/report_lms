//
//  ProgressViewModel.swift
//  report_lms
//

import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
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

        let inspections = storageService.getAllInspections().filter { $0.status == .inProgress }
        let sections = groupInspectionsByWeekUseCase.execute(inspections)
        weeklyInspections = sections
    }

    func visibleInspections(for section: WeekSection) -> [Inspection] {
        section.inspections
    }

    func deleteInspection(_ inspection: Inspection) async {
        do {
            try await storageService.deleteInspection(by: inspection.id)
            await loadInspections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetInspection(_ inspection: Inspection) async {
        var reset = inspection
        reset.sections = reset.sections.map { section in
            var s = section
            s.fields = s.fields.map { field in
                var f = field
                f.photoURL = nil
                f.imageURLs = []
                return f
            }
            return s
        }
        do {
            try await storageService.updateInspection(reset)
            await loadInspections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
