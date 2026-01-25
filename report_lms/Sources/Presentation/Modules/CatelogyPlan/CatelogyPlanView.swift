//
//  CatelogyPlanView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import SwiftUI

struct CatelogyPlanView: View {
    // MARK: - Properties
    @StateObject private var viewModel: CatelogyPlanViewModel
    @Environment(\.dismiss) private var dismiss
    var onCombineInspection: () -> Void = {}
    var onScanBarcode: () -> Void = {}
    var onStartInspection: () -> Void = {}
    var onQuickInspection: () -> Void = {}
    
    init(viewModel: CatelogyPlanViewModel, 
         onCombineInspection: @escaping () -> Void = {},
         onScanBarcode: @escaping () -> Void = {},
         onStartInspection: @escaping () -> Void = {},
         onQuickInspection: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCombineInspection = onCombineInspection
        self.onScanBarcode = onScanBarcode
        self.onStartInspection = onStartInspection
        self.onQuickInspection = onQuickInspection
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            contentView
                .padding(.top, 8)
            Spacer().frame(height: 32)
            cancelButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.items, id: \.self) { option in
                optionRow(option)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func optionRow(_ option: CatelogyPlanViewModel.InspectionOption) -> some View {
        Button(action: {
            handleOptionTap(option)
        }) {
            HStack(spacing: 16) {
                LMSLabel(option.title,
                         style: .body,
                         color: .primary,
                         alignment: .leading)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, option == viewModel.items.first ? 0 : 6)
        .padding(.bottom, 6)
    }
    
    private var cancelButton: some View {
        Button(action: {
            dismiss()
        }) {
            LMSLabel("HỦY BỎ",
                     style: .body,
                     color: .primary,
                     alignment: .center)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Private Methods
    private func handleOptionTap(_ option: CatelogyPlanViewModel.InspectionOption) {
        dismiss()
        
        switch option {
        case .combine:
            onCombineInspection()
        case .scanBarcode:
            onScanBarcode()
        case .startInspection:
            onStartInspection()
        case .quickInspection:
            onQuickInspection()
        }
    }
}

// MARK: - InspectionOption Enum

extension CatelogyPlanView {
    
}

// MARK: - Preview

#Preview {
    let viewModel = CatelogyPlanViewModel()
    CatelogyPlanView(viewModel: viewModel)
        .presentationDetents([.medium])
}
