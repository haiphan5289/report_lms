//
//  PlanLMSHomeView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/1/26.
//

import SwiftUI

struct PlanLMSHomeView: View {
        @State private var showSheet = false

        var body: some View {
            ZStack(alignment: .top) {
                Text("Hello, World!")
            
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingButton
                        Spacer().frame(width: 32)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showSheet) {
                let viewModel = CatelogyPlanViewModel()
                CatelogyPlanView(viewModel: viewModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
        }
    
    private var floatingButton: some View {
        // Floating Action Button
        LMSButton("", icon: "plus", variant: .iconOnly, action: {
            showSheet = true
        })
        .frame(width: 56, height: 56)
        .background(Circle().fill(Color.primary))
        .foregroundColor(.white)
        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
        .padding([.bottom, .trailing], 24)
    }
}

#Preview {
    PlanLMSHomeView()
}
