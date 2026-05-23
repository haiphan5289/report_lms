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
    @State private var rowsVisible = false
    @State private var cancelVisible = false
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
        .task {
            withAnimation(.easeOut(duration: 0.3)) { rowsVisible = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) { cancelVisible = true }
        }
    }

    // MARK: - Private Views
    private var contentView: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element) { index, option in
                optionRow(option, index: index)
            }
        }
        .background(Color(.systemBackground))
    }

    private func optionRow(_ option: CatelogyPlanViewModel.InspectionOption, index: Int) -> some View {
        Button {
            handleOptionTap(option)
        } label: {
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
        .buttonStyle(ScalePressStyle())
        .padding(.horizontal, 12)
        .padding(.top, option == viewModel.items.first ? 0 : 6)
        .padding(.bottom, 6)
        .opacity(rowsVisible ? 1 : 0)
        .offset(y: rowsVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.07), value: rowsVisible)
    }

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            LMSLabel("HỦY BỎ",
                     style: .body,
                     color: .primary,
                     alignment: .center)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(ScalePressStyle())
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .opacity(cancelVisible ? 1 : 0)
        .offset(y: cancelVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.3), value: cancelVisible)
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

// MARK: - Button Style

private struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = CatelogyPlanViewModel()
    CatelogyPlanView(viewModel: viewModel)
        .presentationDetents([.medium])
}
