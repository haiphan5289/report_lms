//
//  SendEmailListViewModel.swift
//  report_lms
//

import Foundation
import SwiftUI

@MainActor
final class SendEmailListViewModel: ObservableObject {

    // MARK: - Published

    @Published var allTasks: [ReportDeliveryTask] = []
    @Published var selectedFilter: FilterOption = .all
    @Published var selectedTask: ReportDeliveryTask?
    @Published var showDetail: Bool = false
    @Published var isRetrying: Bool = false
    @Published var isLoading: Bool = true
    @Published var isDeleting: Bool = false
    @Published var showDeleteAllAlert: Bool = false
    @Published var taskPendingDelete: ReportDeliveryTask?
    @Published var showDeleteSingleAlert: Bool = false
    @Published var errorMessage: String?

    // MARK: - Filter

    enum FilterOption: String, CaseIterable {
        case all
        case sent
        case failed
        case processing

        var label: String {
            switch self {
            case .all:        return "Tất cả"
            case .sent:       return "Đã gửi"
            case .failed:     return "Thất bại"
            case .processing: return "Đang gửi"
            }
        }

        var icon: String {
            switch self {
            case .all:        return "tray.full"
            case .sent:       return "checkmark.circle"
            case .failed:     return "xmark.circle"
            case .processing: return "arrow.triangle.2.circlepath"
            }
        }
    }

    // MARK: - Computed

    var filteredTasks: [ReportDeliveryTask] {
        switch selectedFilter {
        case .all:        return allTasks
        case .sent:       return allTasks.filter { $0.status == .sent }
        case .failed:     return allTasks.filter { $0.status == .failed }
        case .processing: return allTasks.filter { $0.status == .processing || $0.status == .queued }
        }
    }

    var sentCount: Int { allTasks.filter { $0.status == .sent }.count }
    var failedCount: Int { allTasks.filter { $0.status == .failed }.count }

    // MARK: - Private

    private let queueService: ReportDeliveryQueueService
    private var listenerTask: Task<Void, Never>?

    // MARK: - Init

    init(queueService: ReportDeliveryQueueService) {
        self.queueService = queueService
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard listenerTask == nil else { return }
        listenerTask = Task {
            for await tasks in queueService.allTasksStream() {
                self.allTasks = tasks
                if isLoading { isLoading = false }
            }
        }
    }

    func onDisappear() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    // MARK: - Actions

    func selectTask(_ task: ReportDeliveryTask) {
        selectedTask = task
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showDetail = true
        }
    }

    func retryTask() {
        guard let task = selectedTask, task.status == .failed else { return }
        isRetrying = true
        Task {
            do {
                try await queueService.retryTask(taskId: task.id)
                if let idx = allTasks.firstIndex(where: { $0.id == task.id }) {
                    allTasks[idx].status = .queued
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showDetail = false
                }
            } catch {
                errorMessage = "Không thể gửi lại: \(error.localizedDescription)"
            }
            isRetrying = false
        }
    }

    // MARK: - Delete

    /// Called from swipe action or detail sheet delete button — shows confirmation.
    func requestDeleteTask(_ task: ReportDeliveryTask) {
        taskPendingDelete = task
        showDeleteSingleAlert = true
    }

    /// Confirmed single delete — removes from Firestore and local list.
    func confirmDeleteTask() {
        guard let task = taskPendingDelete else { return }
        // Optimistically remove from local list immediately
        withAnimation(.easeOut(duration: 0.3)) {
            allTasks.removeAll { $0.id == task.id }
        }
        // Close detail sheet if the deleted task was selected
        if selectedTask?.id == task.id {
            withAnimation { showDetail = false }
        }
        taskPendingDelete = nil
        Task {
            do {
                try await queueService.deleteTask(taskId: task.id)
            } catch {
                errorMessage = "Không thể xóa: \(error.localizedDescription)"
            }
        }
    }

    /// Deletes all currently visible (filtered) tasks.
    func confirmDeleteAll() {
        let tasksToDelete = filteredTasks
        guard !tasksToDelete.isEmpty else { return }
        let ids = tasksToDelete.map { $0.id }
        isDeleting = true
        // Optimistically remove from local list
        withAnimation(.easeOut(duration: 0.3)) {
            allTasks.removeAll { ids.contains($0.id) }
        }
        if let selected = selectedTask, ids.contains(selected.id) {
            withAnimation { showDetail = false }
        }
        Task {
            do {
                try await queueService.deleteTasks(taskIds: ids)
            } catch {
                errorMessage = "Xóa thất bại: \(error.localizedDescription)"
            }
            isDeleting = false
        }
    }

    var deleteAllLabel: String {
        let count = filteredTasks.count
        return count > 0 ? "Xóa \(count) email" : "Xóa tất cả"
    }
}
