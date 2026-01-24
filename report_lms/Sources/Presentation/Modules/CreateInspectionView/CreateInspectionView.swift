//
//  CreateInspectionView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import SwiftUI

struct CreateInspectionView: View {
    @StateObject private var viewModel: CreateInspectionViewModel
    @State private var showingInspectionTypePicker = false
    
    init(viewModel: CreateInspectionViewModel = CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!)) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(viewModel.inputFields.indices, id: \.self) { index in
                        let field = viewModel.inputFields[index]
                        ProductInfoInput(
                            title: field.title,
                            text: field.text,
                            type: field.type,
                            onDropdownTap: field.onDropdownTap,
                            errorMessage: errorMessageForIndex(index)
                        )
                    }
                    
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
                    
                    if let inspection = viewModel.createdInspection {
                        successView(inspection: inspection)
                    }
                }
                .padding()
            }
            .navigationTitle("Tạo kiểm tra")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingInspectionTypePicker) {
                InspectionTypePickerView(
                    selectedType: $viewModel.inspectionType,
                    types: [
                        "Kiểm tra chất lượng",
                        "Kiểm tra an toàn",
                        "Kiểm tra kỹ thuật",
                        "Kiểm tra định kỳ"
                    ],
                    isPresented: $showingInspectionTypePicker
                )
            }
            .onAppear {
                viewModel.configureDropdownTapHandler {
                    showingInspectionTypePicker = true
                }
            }
        }
    }
    
    private func errorMessageForIndex(_ index: Int) -> String? {
        switch index {
        case 0: return viewModel.productNameError
        case 1: return viewModel.productCodeError
        case 2: return viewModel.orderCodeError
        case 3: return viewModel.inspectionTypeError
        default: return nil
        }
    }
    
    private func successView(inspection: Inspection) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            LMSLabel("Tạo kiểm tra thành công!", style: .headline, alignment: .center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Mã kiểm tra: \(inspection.id)")
                Text("Sản phẩm: \(inspection.productName)")
                Text("Loại: \(inspection.inspectionType)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            LMSButton("Tạo kiểm tra mới", variant: .secondary) {
                viewModel.resetForm()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InspectionTypePickerView: View {
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

#Preview {
    CreateInspectionView()
}
