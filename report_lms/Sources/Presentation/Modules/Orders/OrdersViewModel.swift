//
//  OrdersViewModel.swift
//  report_lms
//

import Foundation
import Combine

@MainActor
final class OrdersViewModel: ObservableObject {
    // MARK: - Published
    @Published var inspections: [Inspection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedStatus: InspectionStatus? = nil

    // MARK: - Private
    private let storageService: InspectionStorageServiceType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    nonisolated init(storageService: InspectionStorageServiceType) {
        self.storageService = storageService

        Task { @MainActor in
            for name in [Notification.Name.inspectionCacheDidLoad, .inspectionDidUpdate] {
                NotificationCenter.default.publisher(for: name)
                    .sink { [weak self] _ in
                        Task { @MainActor in
                            await self?.loadOrders()
                        }
                    }
                    .store(in: &self.cancellables)
            }
        }
    }

    // MARK: - Computed

    var filteredInspections: [Inspection] {
        var result = inspections
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.inspectionNumber.lowercased().contains(q) ||
                $0.productName.lowercased().contains(q) ||
                $0.orderCode.lowercased().contains(q) ||
                $0.factory.lowercased().contains(q)
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var countAll: Int { inspections.count }
    var countPlan: Int { inspections.filter { $0.status == .plan }.count }
    var countInProgress: Int { inspections.filter { $0.status == .inProgress }.count }
    var countCompleted: Int { inspections.filter { $0.status == .completed }.count }

    // MARK: - Methods

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        inspections = storageService.getAllInspections()
    }

    func updateStatus(id: String, to newStatus: InspectionStatus) async {
        guard let index = inspections.firstIndex(where: { $0.id == id }),
              inspections[index].status != newStatus else { return }
        // Optimistic update — reflect immediately in UI
        let previousStatus = inspections[index].status
        inspections[index].status = newStatus
        do {
            try await storageService.updateInspectionStatus(inspectionId: id, status: newStatus)
        } catch {
            // Rollback on failure
            if let idx = inspections.firstIndex(where: { $0.id == id }) {
                inspections[idx].status = previousStatus
            }
            errorMessage = "Không thể đổi trạng thái đơn hàng"
        }
    }

    func deleteInspection(id: String) async {
        // Optimistic update — remove immediately from UI
        let backup = inspections
        inspections.removeAll { $0.id == id }
        do {
            try await storageService.deleteInspection(by: id)
        } catch {
            // Rollback on failure
            inspections = backup
            errorMessage = "Không thể xóa đơn hàng"
        }
    }
}
