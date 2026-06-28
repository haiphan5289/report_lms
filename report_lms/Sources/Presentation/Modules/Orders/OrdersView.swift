//
//  OrdersView.swift
//  report_lms
//

import SwiftUI

// MARK: - OrdersView

struct OrdersView: View {
    @StateObject private var viewModel: OrdersViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var inspectionToDelete: Inspection?
    @State private var inspectionToDetail: Inspection?

    // Animation
    @State private var listVisible = false
    @State private var floatOffset: CGFloat = -6

    init(viewModel: OrdersViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? Container.shared.resolve(OrdersViewModel.self)!
        )
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && viewModel.inspections.isEmpty {
                LMSLoadingView()
            } else if let error = viewModel.errorMessage, viewModel.inspections.isEmpty {
                errorView(message: error)
            } else {
                mainContent
            }
        }
        .navigationTitle(localizationManager.localize("orders.title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadOrders() }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { listVisible = true } }
        .refreshable { await viewModel.loadOrders() }
        .sheet(item: $inspectionToDetail) { inspection in
            OrderDetailBottomSheet(inspection: inspection)
        }
        .sheet(item: $inspectionToDelete) { inspection in
            DeleteConfirmationView(
                title: localizationManager.localize("orders.delete.title"),
                message: String(format: localizationManager.localize("orders.delete.message"),
                    inspection.inspectionNumber.isEmpty
                        ? localizationManager.localize("orders.delete.defaultName")
                        : inspection.inspectionNumber),
                confirmTitle: localizationManager.localize("orders.delete.confirm")
            ) {
                Task { await viewModel.deleteInspection(id: inspection.id) }
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .opacity(listVisible ? 1 : 0)
                    .offset(y: listVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4), value: listVisible)

                searchBar
                    .padding(.horizontal, 16)

                filterChips
                    .padding(.horizontal, 16)

                if viewModel.filteredInspections.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    orderList
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            StatCard(value: viewModel.countAll, label: localizationManager.localize("orders.stats.all"), color: .blue)
            StatCard(value: viewModel.countPlan, label: localizationManager.localize("orders.stats.plan"), color: Color(.systemBlue))
            StatCard(value: viewModel.countInProgress, label: localizationManager.localize("orders.stats.inProgress"), color: .orange)
            StatCard(value: viewModel.countCompleted, label: localizationManager.localize("orders.stats.completed"), color: .green)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            TextField(localizationManager.localize("orders.search.placeholder"), text: $viewModel.searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LMSColor.background)
        .cornerRadius(10)
        .shadow(color: LMSColor.Shadow.subtle, radius: 2, y: 1)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: localizationManager.localize("orders.filter.all"), isSelected: viewModel.selectedStatus == nil) {
                    viewModel.selectedStatus = nil
                }
                ForEach(InspectionStatus.allCases, id: \.self) { status in
                    FilterChip(
                        label: status.displayName,
                        isSelected: viewModel.selectedStatus == status
                    ) {
                        viewModel.selectedStatus = (viewModel.selectedStatus == status) ? nil : status
                    }
                }
            }
        }
    }

    // MARK: - Order List

    private var orderList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(viewModel.filteredInspections.enumerated()), id: \.element.id) { index, inspection in
                OrderCardView(
                    inspection: inspection,
                    onTap: { inspectionToDetail = inspection },
                    onDelete: { inspectionToDelete = inspection }
                )
                .padding(.horizontal, 16)
                .opacity(listVisible ? 1 : 0)
                .offset(y: listVisible ? 0 : 16)
                .animation(
                    .easeOut(duration: 0.35).delay(Double(min(index, 6)) * 0.08),
                    value: listVisible
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.searchText.isEmpty ? "cart" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
                .offset(y: floatOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        floatOffset = 6
                    }
                }
            LMSLabel(
                viewModel.searchText.isEmpty
                    ? localizationManager.localize("orders.empty")
                    : localizationManager.localize("orders.empty.search"),
                style: .body,
                color: .secondary,
                alignment: .center
            )
            if !viewModel.searchText.isEmpty {
                LMSButton(localizationManager.localize("orders.clearFilter"), variant: .ghost, size: .small) {
                    viewModel.searchText = ""
                    viewModel.selectedStatus = nil
                }
            }
        }
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            LMSLabel(message, style: .body, color: .secondary, alignment: .center)
                .padding(.horizontal, 32)
            LMSButton(localizationManager.localize("common.retry"), icon: "arrow.clockwise", variant: .primary) {
                Task { await viewModel.loadOrders() }
            }
            .frame(maxWidth: 180)
            .frame(height: 44)
        }
    }
}

// MARK: - OrderCardView

struct OrderCardView: View {
    let inspection: Inspection
    let onTap: () -> Void
    let onDelete: () -> Void

    @GestureState private var cardPressed = false

    var body: some View {
        HStack(spacing: 0) {
            // Colored left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(inspection.status.accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Number + Status badge + Delete button
                HStack {
                    LMSLabel(
                        inspection.inspectionNumber.isEmpty ? "---" : inspection.inspectionNumber,
                        style: .headline
                    )
                    Spacer()
                    StatusBadge(status: inspection.status)
                    LMSButton("", icon: "trash", variant: .iconOnly, action: onDelete)
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                }

                Divider()

                // Row 2: Company
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    LMSLabel(
                        inspection.companyName.isEmpty ? "---" : inspection.companyName,
                        style: .subheadline
                    )
                }

                // Row 3: Product
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    LMSLabel(inspection.productName, style: .body)
                    if !inspection.productCode.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                        LMSLabel(inspection.productCode, style: .caption, color: .secondary)
                    }
                }

                // Row 4: Factory + Date
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        LMSLabel(
                            inspection.factory.isEmpty ? "---" : inspection.factory,
                            style: .caption,
                            color: .secondary
                        )
                    }
                    Spacer()
                    LMSLabel(inspection.formattedDate, style: .caption, color: .secondary)
                }

                // Row 5: Order code chip
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    LMSLabel(
                        inspection.orderCode.isEmpty ? "---" : inspection.orderCode,
                        style: .caption,
                        color: .primary
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
            }
            .padding(14)
        }
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: LMSColor.Shadow.medium, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LMSColor.Border.subtle, lineWidth: 1)
        )
        .scaleEffect(cardPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: cardPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($cardPressed) { _, state, _ in state = true }
                .onEnded { _ in onTap() }
        )
    }
}

// MARK: - Preview

// MARK: - Preview Helpers

private let previewInspections: [Inspection] = [
    Inspection(
        id: "1",
        inspectionNumber: "INS-2026-001",
        companyName: "Công ty TNHH ABC",
        productName: "Áo thun cotton",
        productCode: "AT-001",
        orderCode: "ORD-2026-001",
        inspectionType: "Final Inspection",
        quantity: "1000",
        factory: "Nhà máy Hà Nội",
        productionUnit: "Pcs",
        createdAt: Date(),
        status: .plan
    ),
    Inspection(
        id: "2",
        inspectionNumber: "INS-2026-002",
        companyName: "Công ty TNHH XYZ",
        productName: "Quần jean nam",
        productCode: "QJ-002",
        orderCode: "ORD-2026-002",
        inspectionType: "During Production",
        quantity: "500",
        factory: "Nhà máy TP.HCM",
        productionUnit: "Pcs",
        createdAt: Date().addingTimeInterval(-86400),
        status: .inProgress
    ),
    Inspection(
        id: "3",
        inspectionNumber: "INS-2026-003",
        companyName: "Công ty TNHH DEF",
        productName: "Váy công sở",
        productCode: "VCS-003",
        orderCode: "ORD-2026-003",
        inspectionType: "Pre-shipment",
        quantity: "800",
        factory: "Nhà máy Đà Nẵng",
        productionUnit: "Pcs",
        createdAt: Date().addingTimeInterval(-172800),
        status: .completed
    ),
    Inspection(
        id: "4",
        inspectionNumber: "INS-2026-004",
        companyName: "Công ty TNHH GHI",
        productName: "Áo khoác nam",
        productCode: "AK-004",
        orderCode: "ORD-2026-004",
        inspectionType: "Final Inspection",
        quantity: "600",
        factory: "Nhà máy Hải Phòng",
        productionUnit: "Pcs",
        createdAt: Date().addingTimeInterval(-259200),
        status: .error
    ),
    Inspection(
        id: "5",
        inspectionNumber: "INS-2026-005",
        companyName: "Công ty TNHH JKL",
        productName: "Giày sneaker",
        productCode: "GS-005",
        orderCode: "ORD-2026-005",
        inspectionType: "Pre-shipment",
        quantity: "1200",
        factory: "Nhà máy Bình Dương",
        productionUnit: "Pairs",
        createdAt: Date().addingTimeInterval(-432000),
        status: .cancelled
    )
]

@MainActor
private func makePreviewViewModel(inspections: [Inspection] = previewInspections) -> OrdersViewModel {
    final class MockStorage: InspectionStorageServiceType {
        private var items: [Inspection]
        let isCacheLoaded = true
        init(_ items: [Inspection]) { self.items = items }
        func loadCache() async throws {}
        func getAllInspections() -> [Inspection] { items }
        func getInspection(by id: String) -> Inspection? { items.first { $0.id == id } }
        func saveInspection(_ i: Inspection) async throws { items.append(i) }
        func updateInspection(_ i: Inspection) async throws {
            if let idx = items.firstIndex(where: { $0.id == i.id }) { items[idx] = i }
        }
        @MainActor func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String], imageDescriptions: [String]) async throws {}
        func updateInspectionStatus(inspectionId: String, status: InspectionStatus) async throws {}
        func deleteInspection(by id: String) async throws { items.removeAll { $0.id == id } }
        func getDraftInspections() -> [Inspection] { items.filter { $0.status == .plan || $0.status == .inProgress } }
        func getCompletedInspections() -> [Inspection] { items.filter { $0.status == .completed } }
    }
    let vm = OrdersViewModel(storageService: MockStorage(inspections))
    vm.inspections = inspections
    return vm
}

#Preview("With Data") {
    NavigationView {
        OrdersView(viewModel: makePreviewViewModel())
    }
    .environmentObject(LocalizationManager.shared)
}

#Preview("Empty") {
    NavigationView {
        OrdersView(viewModel: makePreviewViewModel(inspections: []))
    }
    .environmentObject(LocalizationManager.shared)
}

#Preview("Loading") {
    NavigationView {
        OrdersView(viewModel: {
            let vm = makePreviewViewModel(inspections: [])
            vm.isLoading = true
            return vm
        }())
    }
    .environmentObject(LocalizationManager.shared)
}
