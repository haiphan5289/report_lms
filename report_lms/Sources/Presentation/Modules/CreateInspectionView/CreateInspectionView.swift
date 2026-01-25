//
//  CreateInspectionView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import SwiftUI

// MARK: - Constants
private enum InspectionTypes {
    static let all = [
        "Kiểm tra chất lượng",
        "Kiểm tra an toàn",
        "Kiểm tra kỹ thuật",
        "Kiểm tra định kỳ"
    ]
}

// MARK: - Array Extension for Safe Access
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Success View Component
private struct SuccessView: View {
    let inspection: Inspection
    let onCreateNew: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            LMSLabel("Tạo kiểm tra thành công!", style: .headline, alignment: .center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Mã kiểm tra: \(inspection.id)")
                Text("Sản phẩm: \(inspection.productName)")
                Text("Loại: \(inspection.inspectionType)")
                Text("Số lượng: \(inspection.quantity)")
                Text("Nhà máy: \(inspection.factory)")
                Text("Đơn vị sản xuất: \(inspection.productionUnit)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            LMSButton("Tạo kiểm tra mới", variant: .secondary, action: onCreateNew)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@MainActor
struct CreateInspectionView: View {
    // MARK: - Properties
    @StateObject private var viewModel: CreateInspectionViewModel
    @State private var showingInspectionTypePicker = false
    
    // MARK: - Initialization
    init(viewModel: CreateInspectionViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    inputFieldsSection
                }
                .padding()
            }
            createButtonSection
            successSection
        }
        .navigationTitle("Tạo kiểm tra")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInspectionTypePicker) {
            InspectionTypePickerView(
                selectedType: $viewModel.inspectionType,
                types: InspectionTypes.all,
                isPresented: $showingInspectionTypePicker
            )
        }
        .onAppear {
            viewModel.configureDropdownTapHandler {
                showingInspectionTypePicker = true
            }
        }
    }
    
    // MARK: - Private Views
    private var inputFieldsSection: some View {
        ForEach(viewModel.inputFields.indices, id: \.self) { index in
            let field = viewModel.inputFields[index]
            if field.type == .quantity {
                QuantityInputView(
                    labelText: field.title,
                    placeholder: "Nhập số lượng",
                    text: field.text
                )
            } else {
                ProductInfoInput(
                    title: field.title,
                    text: field.text,
                    type: field.type,
                    onDropdownTap: field.onDropdownTap,
                    errorMessage: viewModel.fieldErrors[safe: index] ?? nil
                )
            }
        }
    }
    
    private var createButtonSection: some View {
        VStack {
            LMSButton(
                "Tạo kiểm tra",
                variant: .primary,
                isFullWidth: true,
                isLoading: $viewModel.isLoading
            ) {
                Task {
                    await viewModel.createInspection()
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private var successSection: some View {
        Group {
            if let inspection = viewModel.createdInspection {
                SuccessView(inspection: inspection) {
                    viewModel.resetForm()
                }
            }
        }
    }
}

// MARK: - Inspection Type Picker Component
private struct InspectionTypePickerView: View {
    @Binding var selectedType: String
    let types: [String]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(types, id: \.self) { type in
                Button(action: {
                    selectedType = type
                    isPresented = false
                }) {
                    HStack {
                        Text(type)
                        Spacer()
                        if selectedType == type {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Chọn loại kiểm tra")
            .navigationBarItems(trailing: Button("Đóng") {
                isPresented = false
            })
        }
    }
}

// MARK: - Preview
#Preview {
    CreateInspectionView()
}
