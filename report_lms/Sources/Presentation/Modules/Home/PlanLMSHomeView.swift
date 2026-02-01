//
//  PlanLMSHomeView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/1/26.
//

import SwiftUI

// MARK: - PlanLMSHomeView

struct PlanLMSHomeView: View {
    // MARK: - Properties
    @StateObject private var viewModel: PlanLMSHomeViewModel
    @State private var navigationPath = NavigationPath()
    let onQuickInspection: () -> Void
    
    // MARK: - Initialization
    init(
        viewModel: PlanLMSHomeViewModel? = nil,
        onQuickInspection: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel ?? Container.shared.resolve(PlanLMSHomeViewModel.self)!)
        self.onQuickInspection = onQuickInspection
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                contentView
                floatingButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: String.self) { destination in
                if destination == "createInspection" {
                    let createViewModel = CreateInspectionViewModel(
                        createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!
                    )
                    CreateInspectionView(viewModel: createViewModel) { createdInspection in
                        viewModel.addNewInspection(createdInspection)
                    }
                }
            }
            .navigationDestination(for: Inspection.self) { inspection in
                InspectionDetailView(
                    inspectionId: inspection.id,
                    inspectionNumber: inspection.inspectionNumber
                )
            }
            .task {
                await viewModel.loadInspections()
            }
            .refreshable {
                await viewModel.loadInspections()
            }
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
            
            LMSButton("Thử lại", icon: "arrow.clockwise", variant: .primary, action: {
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
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.6))
                LMSLabel("Không có yêu cầu kiểm tra nào được tải xuống", style: .body, alignment: .center)
                LMSLabel("Nhấn button bên dưới để xem thêm", style: .subheadline, color: .secondary, alignment: .center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            LMSButton("Tải thêm yêu cầu kiểm hàng", icon: "arrow.clockwise", variant: .primary, action: {
                Task {
                    await viewModel.loadInspections()
                }
            })
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding()
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
                                        isLastIndex: index == visibleInspections.count - 1
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
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
    
    private var floatingButton: some View {
        HStack {
            Spacer()
            Button(action: onQuickInspection) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(Color.blue))
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            .padding([.bottom, .trailing], 24)
        }
    }
}

// MARK: - Preview Helpers

// Mock service that returns preview data
private final class PreviewInspectionService: InspectionServiceType {
    private let mockInspections: [InspectionModel]
    
    init(inspections: [Inspection]) {
        self.mockInspections = inspections.map { InspectionModel.fromEntity($0) }
    }
    
    func createInspection(_ model: InspectionModel) async throws -> InspectionModel {
        model
    }
    
    func getInspections() async throws -> [InspectionModel] {
        mockInspections
    }
    
    func getInspection(id: String) async throws -> InspectionModel {
        guard let inspection = mockInspections.first(where: { $0.id == id }) else {
            throw NSError(domain: "PreviewService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        }
        return inspection
    }
}

@MainActor
private func createPreviewViewModel() -> PlanLMSHomeViewModel {
    // Create mock inspection data
    let mockInspections = [
        Inspection(
            id: "1",
            inspectionNumber: "INS-2026-001",
            companyName: "Công ty TNHH ABC",
            productName: "Áo thun cotton",
            productCode: "AT-001",
            orderCode: "ORD-2026-001",
            inspectionType: "Kiểm tra chất lượng",
            quantity: "1000",
            factory: "Nhà máy Hà Nội",
            productionUnit: "Xưởng sản xuất 1",
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
            inspectionType: "Kiểm tra cuối cùng",
            quantity: "500",
            factory: "Nhà máy TP.HCM",
            productionUnit: "Xưởng sản xuất 2",
            createdAt: Date().addingTimeInterval(-86400),
            status: .plan
        ),
        Inspection(
            id: "3",
            inspectionNumber: "INS-2026-003",
            companyName: "Công ty TNHH DEF",
            productName: "Váy công sở",
            productCode: "VCS-003",
            orderCode: "ORD-2026-003",
            inspectionType: "Kiểm tra trong quá trình",
            quantity: "800",
            factory: "Nhà máy Đà Nẵng",
            productionUnit: "Xưởng sản xuất 3",
            createdAt: Date().addingTimeInterval(-172800),
            status: .plan
        ),
        Inspection(
            id: "4",
            inspectionNumber: "INS-2026-004",
            companyName: "Công ty TNHH GHI",
            productName: "Áo khoác nam",
            productCode: "AK-004",
            orderCode: "ORD-2026-004",
            inspectionType: "Kiểm tra chất lượng",
            quantity: "600",
            factory: "Nhà máy Hà Nội",
            productionUnit: "Xưởng sản xuất 1",
            createdAt: Date().addingTimeInterval(-259200),
            status: .plan
        ),
        Inspection(
            id: "5",
            inspectionNumber: "INS-2026-005",
            companyName: "Công ty TNHH JKL",
            productName: "Áo sơ mi nữ",
            productCode: "ASM-005",
            orderCode: "ORD-2026-005",
            inspectionType: "Kiểm tra cuối cùng",
            quantity: "1200",
            factory: "Nhà máy Biên Hòa",
            productionUnit: "Xưởng sản xuất 4",
            createdAt: Date().addingTimeInterval(-604800),
            status: .plan
        ),
        Inspection(
            id: "6",
            inspectionNumber: "INS-2026-006",
            companyName: "Công ty TNHH MNO",
            productName: "Quần tây nam",
            productCode: "QT-006",
            orderCode: "ORD-2026-006",
            inspectionType: "Kiểm tra chất lượng",
            quantity: "700",
            factory: "Nhà máy Hải Phòng",
            productionUnit: "Xưởng sản xuất 5",
            createdAt: Date().addingTimeInterval(-691200),
            status: .plan
        )
    ]
    
    // Create mock service that returns our data
    let mockService = PreviewInspectionService(inspections: mockInspections)
    let mockRepository = InspectionRepository(service: mockService)
    let mockFetchUseCase = FetchInspectionsUseCase(repository: mockRepository)
    let mockGroupUseCase = GroupInspectionsByWeekUseCase()
    
    let viewModel = PlanLMSHomeViewModel(
        fetchInspectionsUseCase: mockFetchUseCase,
        groupInspectionsByWeekUseCase: mockGroupUseCase,
        repository: mockRepository
    )
    
    return viewModel
}

#Preview {
    PlanLMSHomeView(viewModel: createPreviewViewModel())
}
