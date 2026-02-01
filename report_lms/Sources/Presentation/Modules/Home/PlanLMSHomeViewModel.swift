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
    private var fetchInspectionsUseCase: FetchInspectionsUseCase
    private var groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase
    private var repository: InspectionRepositoryType
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    nonisolated init(
        fetchInspectionsUseCase: FetchInspectionsUseCase,
        groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase,
        repository: InspectionRepositoryType
    ) {
        self.fetchInspectionsUseCase = fetchInspectionsUseCase
        self.groupInspectionsByWeekUseCase = groupInspectionsByWeekUseCase
        self.repository = repository
        
        Task { @MainActor in
            self.setupSubscriptions()
        }
    }
    
    // MARK: - Public Methods
    func loadInspections() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let inspections = try await fetchInspectionsUseCase.execute()
            let sections = groupInspectionsByWeekUseCase.execute(inspections)
            weeklyInspections = sections
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func visibleInspections(for section: WeekSection) -> [Inspection] {
        section.inspections
    }
    
    func addNewInspection(_ inspection: Inspection) {
        // The repository already updated the inspectionsSubject when createInspection was called
        // The setupSubscriptions() will receive this update automatically
    }
    
    private func getAllInspections() -> [Inspection] {
        weeklyInspections.flatMap { $0.inspections }
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        repository.inspectionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inspections in
                guard let self = self else { return }
                let sections = self.groupInspectionsByWeekUseCase.execute(inspections)
                self.weeklyInspections = sections
            }
            .store(in: &cancellables)
    }
}
