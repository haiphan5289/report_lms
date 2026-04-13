//
//  ProgressView.swift
//  report_lms
//

import SwiftUI

// MARK: - LMSProgressView

struct LMSProgressView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ProgressViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager

    // MARK: - Initialization
    init(viewModel: ProgressViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? Container.shared.resolve(ProgressViewModel.self)!)
    }

    // MARK: - Body
    var body: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await viewModel.loadInspections()
            }
            .refreshable {
                await viewModel.loadInspections()
            }
    }

    // MARK: - Private Views
    private var contentView: some View {
        Group {
            if viewModel.isLoading && viewModel.weeklyInspections.isEmpty {
                LMSLoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.weeklyInspections.isEmpty {
                emptyStateView
            } else {
                inspectionListView
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            LMSLabel(message, style: .body, alignment: .center)

            LMSButton(localizationManager.localize("common.retry"), icon: "arrow.clockwise", variant: .primary, action: {
                Task {
                    await viewModel.loadInspections()
                }
            })
            .frame(maxWidth: 200)
            .frame(height: 44)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))

            LMSLabel(localizationManager.localize("progress.empty.title"), style: .body, alignment: .center)
            LMSLabel(localizationManager.localize("progress.empty.subtitle"), style: .subheadline, color: .secondary, alignment: .center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectionListView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.weeklyInspections) { section in
                    Section {
                        VStack(spacing: 12) {
                            let visibleInspections = viewModel.visibleInspections(for: section)

                            ForEach(Array(visibleInspections.enumerated()), id: \.element.id) { index, inspection in
                                NavigationLink(value: inspection) {
                                InspectionCardView(
                                        inspection: inspection,
                                        isLastIndex: index == visibleInspections.count - 1,
                                        onDelete: {
                                            Task { await viewModel.deleteInspection(inspection) }
                                        },
                                        onReset: {
                                            Task { await viewModel.resetInspection(inspection) }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LMSColor.background)
                                        .shadow(color: LMSColor.Shadow.medium, radius: 4, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LMSColor.Border.subtle, lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    } header: {
                        sectionHeader(for: section)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func sectionHeader(for section: WeekSection) -> some View {
        HStack {
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            LMSLabel(section.title,
                     style: .subheadline,
                     color: .secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview Helpers

private final class PreviewProgressStorageService: InspectionStorageServiceType {
    private var mockInspections: [Inspection]

    init(inspections: [Inspection]) {
        self.mockInspections = inspections
    }

    func loadCache() async throws {}
    func getAllInspections() -> [Inspection] { mockInspections }
    func getInspection(by id: String) -> Inspection? { mockInspections.first { $0.id == id } }
    func saveInspection(_ inspection: Inspection) async throws { mockInspections.append(inspection) }
    func updateInspection(_ inspection: Inspection) async throws {
        if let index = mockInspections.firstIndex(where: { $0.id == inspection.id }) {
            mockInspections[index] = inspection
        }
    }
    func deleteInspection(by id: String) async throws { mockInspections.removeAll { $0.id == id } }
    func getDraftInspections() -> [Inspection] { mockInspections.filter { $0.status == .plan || $0.status == .inProgress } }
    func getCompletedInspections() -> [Inspection] { mockInspections.filter { $0.status == .completed } }
}

@MainActor
private func makePreviewViewModel(inspections: [Inspection]) -> ProgressViewModel {
    ProgressViewModel(
        storageService: PreviewProgressStorageService(inspections: inspections),
        groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase()
    )
}

private let mockInProgressInspections: [Inspection] = [
    Inspection(
        id: "p1",
        inspectionNumber: "INS-2026-010",
        companyName: "Công ty TNHH ABC",
        productName: "Áo thun cotton",
        productCode: "AT-001",
        orderCode: "ORD-2026-010",
        inspectionType: "Kiểm tra chất lượng",
        quantity: "1000",
        factory: "Nhà máy Hà Nội",
        productionUnit: "Xưởng sản xuất 1",
        createdAt: Date(),
        status: .inProgress
    ),
    Inspection(
        id: "p2",
        inspectionNumber: "INS-2026-011",
        companyName: "Công ty TNHH XYZ",
        productName: "Quần jean nam",
        productCode: "QJ-002",
        orderCode: "ORD-2026-011",
        inspectionType: "Kiểm tra cuối cùng",
        quantity: "500",
        factory: "Nhà máy TP.HCM",
        productionUnit: "Xưởng sản xuất 2",
        createdAt: Date().addingTimeInterval(-86400 * 7),
        status: .inProgress
    )
]

#Preview("With items") {
    let vm = makePreviewViewModel(inspections: mockInProgressInspections)
    NavigationStack {
        LMSProgressView(viewModel: vm)
            .task { await vm.loadInspections() }
    }
    .environmentObject(LocalizationManager.shared)
}

#Preview("Empty state") {
    let vm = makePreviewViewModel(inspections: [])
    NavigationStack {
        LMSProgressView(viewModel: vm)
            .task { await vm.loadInspections() }
    }
    .environmentObject(LocalizationManager.shared)
}
