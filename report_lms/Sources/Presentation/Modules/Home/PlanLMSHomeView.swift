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
    
    // MARK: - Initialization
    init(onQuickInspection: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: PlanLMSHomeViewModel(onQuickInspection: onQuickInspection))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack(alignment: .top) {
                contentView
                floatingButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $viewModel.showSheet) {
                categoryPlanSheet
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "createInspection" {
                    let viewModel = CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!)
                    CreateInspectionView(viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        Text("Hello, World!")
    }
    
    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                LMSButton("", icon: "plus", variant: .iconOnly, action: viewModel.showFloatingButtonAction)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.primary))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                    .padding([.bottom, .trailing], 24)
                Spacer().frame(width: 32)
            }
        }
    }
    
    private var categoryPlanSheet: some View {
        let viewModel = CatelogyPlanViewModel()
        return CatelogyPlanView(viewModel: viewModel, onQuickInspection: self.viewModel.handleQuickInspection)
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
    }
}

// MARK: - Preview

#Preview {
    PlanLMSHomeView()
}
