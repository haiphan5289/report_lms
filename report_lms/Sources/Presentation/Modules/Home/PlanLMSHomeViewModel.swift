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
    @Published var expandedWeeks: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fetchInspectionsUseCase: FetchInspectionsUseCase
    private let groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase
    private let repository: InspectionRepositoryType
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
            setupSubscriptions()
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
    
    func toggleSection(_ sectionId: String) {
        if expandedWeeks.contains(sectionId) {
            expandedWeeks.remove(sectionId)
        } else {
            expandedWeeks.insert(sectionId)
        }
    }
    
    func isExpanded(_ sectionId: String) -> Bool {
        expandedWeeks.contains(sectionId)
    }
    
    func visibleInspections(for section: WeekSection) -> [Inspection] {
        if isExpanded(section.id) {
            return section.inspections
        } else {
            return Array(section.inspections.prefix(3))
        }
    }
    
    func shouldShowExpandButton(for section: WeekSection) -> Bool {
        section.inspections.count > 3
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
