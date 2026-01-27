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
                    CreateInspectionView(viewModel: createViewModel)
                }
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
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.weeklyInspections.isEmpty {
                emptyStateView
            } else {
                inspectionListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            LMSLabel("Đang tải...", style: .body, color: .secondary)
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
                            ForEach(viewModel.visibleInspections(for: section)) { inspection in
                                InspectionCardView(inspection: inspection) {
                                    // TODO: Navigate to detail
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Show expand button inside section
                            if viewModel.shouldShowExpandButton(for: section) {
                                expandCollapseButton(for: section)
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
                .rotationEffect(.degrees(viewModel.isExpanded(section.id) ? 0 : -90))
                .animation(.easeInOut(duration: 0.2), value: viewModel.isExpanded(section.id))
            
            LMSLabel(section.title, 
                    style: .subheadline, 
                    color: .secondary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    private func expandCollapseButton(for section: WeekSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.toggleSection(section.id)
            }
        }) {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    LMSLabel(
                        viewModel.isExpanded(section.id) ? "ẨN BớT" : "HIỆN THỊ TẤT CẢ",
                        style: .caption,
                        color: .custom(Color.blue)
                    )
                    Image(systemName: viewModel.isExpanded(section.id) ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
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

#Preview {
    PlanLMSHomeView()
}
