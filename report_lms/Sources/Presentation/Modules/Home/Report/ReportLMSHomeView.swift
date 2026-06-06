//
//  ReportLMSHomeView.swift
//  report_lms
//

import SwiftUI
import OSLog

private let screenLogger = Logger(subsystem: "com.reportlms", category: "Screen")

// MARK: - ReportLMSHomeView

struct ReportLMSHomeView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ReportViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager

    // Animation
    @State private var listAppeared = false
    @State private var floatOffset: CGFloat = -6
    @State private var selectedInspection: Inspection?

    // MARK: - Initialization
    init(viewModel: ReportViewModel? = nil) {
        guard let resolved = viewModel ?? Container.shared.resolve(ReportViewModel.self) else {
            fatalError("ReportViewModel not registered in DI container")
        }
        _viewModel = StateObject(wrappedValue: resolved)
    }

    // MARK: - Body
    var body: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { screenLogger.debug("▶ ReportLMSHomeView appeared") }
            .onDisappear { screenLogger.debug("◀ ReportLMSHomeView disappeared") }
            .task {
                await viewModel.loadInspections()
            }
            .refreshable {
                await viewModel.loadInspections()
            }
            .sheet(item: $selectedInspection) { inspection in
                InspectionDetailBottomSheet(
                    inspection: inspection,
                    onDelete: {
                        Task { await viewModel.deleteInspection(inspection) }
                    }
                )
            }
    }

    // MARK: - Private Views
    private var contentView: some View {
        ZStack {
            if viewModel.isLoading && viewModel.weeklyInspections.isEmpty {
                skeletonView
                    .transition(.opacity)
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
                    .transition(.opacity)
            } else if viewModel.weeklyInspections.isEmpty {
                emptyStateView
                    .transition(.opacity)
            } else {
                inspectionListView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.35), value: viewModel.weeklyInspections.isEmpty)
    }

    private var skeletonView: some View {
        VStack(spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemFill))
                    .frame(width: 80, height: 14)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    LMSInspectionCardSkeleton()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            LMSLabel(message, style: .body, alignment: .center)

            LMSButton(localizationManager.localize("common.retry"), icon: "arrow.clockwise", variant: .primary, action: {
                Task { await viewModel.loadInspections() }
            })
            .frame(maxWidth: 200)
            .frame(height: 44)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
                .offset(y: floatOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        floatOffset = 6
                    }
                }
            LMSLabel(localizationManager.localize("report.empty.title"), style: .body, alignment: .center)
            LMSLabel(localizationManager.localize("report.empty.subtitle"), style: .subheadline, color: .secondary, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectionListView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.weeklyInspections) { section in
                    Section {
                        VStack(spacing: 12) {
                            let inspections = section.inspections
                            ForEach(Array(inspections.enumerated()), id: \.element.id) { index, inspection in
                                Button(action: { selectedInspection = inspection }) {
                                    InspectionCardView(inspection: inspection)
                                }
                                .buttonStyle(CardPressStyle())
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
                                .opacity(listAppeared ? 1 : 0)
                                .offset(y: listAppeared ? 0 : 16)
                                .animation(
                                    .easeOut(duration: 0.35).delay(Double(min(index, 6)) * 0.08),
                                    value: listAppeared
                                )
                            }
                        }
                        .padding(.vertical, 12)
                        .onAppear { listAppeared = true }
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(LMSColor.success)

            LMSLabel(section.title, style: .subheadline, color: .secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - CardPressStyle

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

@MainActor
private func makePreviewViewModel(inspections: [Inspection]) -> ReportViewModel {
    final class MockStorage: InspectionStorageServiceType {
        private var items: [Inspection]
        let isCacheLoaded: Bool = true
        init(_ items: [Inspection]) { self.items = items }
        func loadCache() async throws {}
        func getAllInspections() -> [Inspection] { items }
        func getInspection(by id: String) -> Inspection? { items.first { $0.id == id } }
        func saveInspection(_ i: Inspection) async throws { items.append(i) }
        func updateInspection(_ i: Inspection) async throws {
            if let idx = items.firstIndex(where: { $0.id == i.id }) { items[idx] = i }
        }
        func deleteInspection(by id: String) async throws { items.removeAll { $0.id == id } }
        func getDraftInspections() -> [Inspection] { items.filter { $0.status == .plan || $0.status == .inProgress } }
        func getCompletedInspections() -> [Inspection] { items.filter { $0.status == .completed } }
    }
    return ReportViewModel(storageService: MockStorage(inspections), groupInspectionsByWeekUseCase: GroupInspectionsByWeekUseCase())
}

private let mockCompleted: [Inspection] = [
    Inspection(
        id: "r1", inspectionNumber: "INS-2026-020",
        companyName: "Công ty TNHH ABC", productName: "Ghế văn phòng",
        productCode: "GVP-001", orderCode: "ORD-2026-020",
        inspectionType: "Final Inspection", quantity: "500",
        factory: "Nhà máy Hà Nội", productionUnit: "Pcs",
        createdAt: Date().addingTimeInterval(-86400 * 3), status: .completed
    ),
    Inspection(
        id: "r2", inspectionNumber: "INS-2026-021",
        companyName: "Công ty TNHH XYZ", productName: "Bàn học sinh",
        productCode: "BHS-002", orderCode: "ORD-2026-021",
        inspectionType: "Pre-shipment", quantity: "1000",
        factory: "Nhà máy TP.HCM", productionUnit: "Pcs",
        createdAt: Date().addingTimeInterval(-86400 * 10), status: .completed
    )
]

#Preview("With items") {
    let vm = makePreviewViewModel(inspections: mockCompleted)
    NavigationStack {
        ReportLMSHomeView(viewModel: vm)
            .task { await vm.loadInspections() }
    }
    .environmentObject(LocalizationManager.shared)
}

#Preview("Empty state") {
    let vm = makePreviewViewModel(inspections: [])
    NavigationStack {
        ReportLMSHomeView(viewModel: vm)
            .task { await vm.loadInspections() }
    }
    .environmentObject(LocalizationManager.shared)
}
