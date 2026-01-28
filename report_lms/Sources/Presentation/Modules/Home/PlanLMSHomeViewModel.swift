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
    
    func addNewInspection(_ inspection: Inspection) {
        print("🟠 [PlanLMSHomeViewModel] addNewInspection() called")
        print("🟠 [PlanLMSHomeViewModel] New inspection ID: \(inspection.id)")
        print("🟠 [PlanLMSHomeViewModel] Product: \(inspection.productName)")
        print("🟠 [PlanLMSHomeViewModel] The repository should have already published this via inspectionsPublisher")
        print("🟠 [PlanLMSHomeViewModel] Current weeklyInspections count: \(weeklyInspections.count)")
        print("🟠 [PlanLMSHomeViewModel] Current sections: \(weeklyInspections.map { $0.id })")
        
        // The repository already updated the inspectionsSubject when createInspection was called
        // The setupSubscriptions() will receive this update automatically
        // We just need to ensure the section is expanded
        
        // Give the publisher a moment to propagate, then expand the first section
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            if let firstSection = weeklyInspections.first {
                print("🟠 [PlanLMSHomeViewModel] Auto-expanding section: \(firstSection.id)")
                expandedWeeks.insert(firstSection.id)
            }
            print("✅ [PlanLMSHomeViewModel] addNewInspection() completed successfully")
        }
    }
    
    private func getAllInspections() -> [Inspection] {
        weeklyInspections.flatMap { $0.inspections }
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        print("🔷 [PlanLMSHomeViewModel] Setting up repository subscriptions")
        repository.inspectionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inspections in
                guard let self = self else { return }
                print("🔷 [PlanLMSHomeViewModel] ===== PUBLISHER FIRED =====")
                print("🔷 [PlanLMSHomeViewModel] Publisher received \(inspections.count) inspections")
                print("🔷 [PlanLMSHomeViewModel] Inspection IDs: \(inspections.map { $0.id })")
                let sections = self.groupInspectionsByWeekUseCase.execute(inspections)
                print("🔷 [PlanLMSHomeViewModel] Grouped into \(sections.count) sections")
                print("🔷 [PlanLMSHomeViewModel] Section details:")
                for section in sections {
                    print("🔷   - Section: \(section.id), Inspections: \(section.inspections.count)")
                }
                print("🔷 [PlanLMSHomeViewModel] Updating weeklyInspections...")
                self.weeklyInspections = sections
                print("🔷 [PlanLMSHomeViewModel] weeklyInspections.count is now: \(self.weeklyInspections.count)")
                print("🔷 [PlanLMSHomeViewModel] Manually triggering objectWillChange...")
                self.objectWillChange.send()
                print("🔷 [PlanLMSHomeViewModel] ===== PUBLISHER UPDATE COMPLETE =====")
            }
            .store(in: &cancellables)
    }
}
