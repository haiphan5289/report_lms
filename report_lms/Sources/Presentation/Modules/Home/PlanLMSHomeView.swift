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
    let onQuickInspection: () -> Void
    @State private var inspections: [InspectionModel] = []
    
    // MARK: - Initialization
    init(onQuickInspection: @escaping () -> Void = {}) {
        self.onQuickInspection = onQuickInspection
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                contentView
                floatingButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: String.self) { destination in
                if destination == "createInspection" {
                    let viewModel = CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!)
                    CreateInspectionView(viewModel: viewModel)
                }
            }
        }
    }
    
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Private Views
    private var contentView: some View {
        Group {
            if inspections.isEmpty {
                emptyStateView
            } else {
                inspectionListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    LMSLabel("Không có yêu cầu kiểm tra nào được tải xuống", style: .body, alignment: .center)
                    LMSLabel("Nhấn button bên dưới để xem thêm", style: .subheadline, color: .secondary, alignment: .center)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            LMSButton("Tải thêm yêu cầu kiểm hàng", icon: "arrow.clockwise", variant: .primary, action: {
                // TODO: Implement load more action
            })
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding()
    }
    
    private var inspectionListView: some View {
        List(inspections, id: \.id) { inspection in
            VStack(alignment: .leading, spacing: 8) {
                LMSLabel(inspection.title ?? "Unknown", style: .headline)
                ForEach(inspection.datas) { dataItem in
                    LMSLabel(dataItem.name, style: .body, color: .secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .listStyle(.plain)
    }
    
    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onQuickInspection) {
                    Image(systemName: "plus")
                }
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.primary))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                    .padding([.bottom, .trailing], 24)
                Spacer().frame(width: 32)
            }
        }
    }
}

#Preview {
    PlanLMSHomeView()
}
