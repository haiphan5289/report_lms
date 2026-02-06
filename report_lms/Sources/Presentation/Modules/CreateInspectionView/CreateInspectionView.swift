//
//  CreateInspectionView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import SwiftUI

// MARK: - Array Extension for Safe Access
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
@MainActor
struct CreateInspectionView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateInspectionViewModel
    @State private var showingSearchableList = false
    @State private var currentDropdownField: InputFieldType?

    var onInspectionCreated: ((Inspection) -> Void)?

    // MARK: - Initialization
    init(viewModel: CreateInspectionViewModel? = nil, onInspectionCreated: ((Inspection) -> Void)? = nil) {
        let viewModel = viewModel ?? CreateInspectionViewModel(
            createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!
        )
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onInspectionCreated = onInspectionCreated
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
        }
        .navigationTitle("Tạo kiểm tra")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSearchableList) {
            if let fieldType = currentDropdownField {
                let searchableData = createSearchableData(for: fieldType)
                let searchableViewModel = SearchableListViewModel(items: searchableData)

                SearchableListView(viewModel: searchableViewModel) { selectedItem in
                    handleDropdownSelection(selectedItem, for: fieldType)
                    showingSearchableList = false // Close the sheet after selection
                }
            }
        }
        .onChange(of: viewModel.createdInspection) { _, newInspection in
            if let inspection = newInspection {
                onInspectionCreated?(inspection)
                dismiss()
            } else {
                print("🔴 [CreateInspectionView] newInspection is nil - not dismissing")
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
                    onDropdownTap: {
                        currentDropdownField = getFieldType(for: field.title)
                        showingSearchableList = true
                    },
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
            .frame(height: 56)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Private Methods
    private func getFieldType(for title: String) -> InputFieldType {
        switch title {
        case "Loại kiểm tra":
            return .inspectionType
        case "Biểu mẫu kiểm hàng":
            return .inspectionForm
        case "Phương pháp lấy mẫu":
            return .samplingMethod
        case "Nhà máy":
            return .factory
        case "Đơn vị sản xuất":
            return .productionUnit
        default:
            return .inspectionType // fallback
        }
    }

    private func createSearchableData(for fieldType: InputFieldType) -> ListItemProtocol {
        switch fieldType {
        case .inspectionType:
            return createInspectionTypeData()
        case .inspectionForm:
            return createInspectionFormData()
        case .samplingMethod:
            return createSamplingMethodData()
        case .factory:
            return createFactoryData()
        case .productionUnit:
            return createProductionUnitData()
        default:
            // These fields don't have dropdown data
            return SampleListItem(title: "", datas: [])
        }
    }

    private func createInspectionTypeData() -> ListItemProtocol {
        return SampleListItem(
            title: "Loại kiểm tra",
            datas: [
                ListDataItem(id: 1, name: "Kiểm tra chất lượng"),
                ListDataItem(id: 2, name: "Kiểm tra an toàn"),
                ListDataItem(id: 3, name: "Kiểm tra định kỳ"),
                ListDataItem(id: 4, name: "Kiểm tra đột xuất")
            ]
        )
    }

    private func createInspectionFormData() -> ListItemProtocol {
        return SampleListItem(
            title: "Biểu mẫu kiểm hàng",
            datas: [
                ListDataItem(id: 1, name: "Biểu mẫu A"),
                ListDataItem(id: 2, name: "Biểu mẫu B"),
                ListDataItem(id: 3, name: "Biểu mẫu C"),
                ListDataItem(id: 4, name: "Biểu mẫu D")
            ]
        )
    }

    private func createSamplingMethodData() -> ListItemProtocol {
        return SampleListItem(
            title: "Phương pháp lấy mẫu",
            datas: [
                ListDataItem(id: 1, name: "Lấy mẫu ngẫu nhiên"),
                ListDataItem(id: 2, name: "Lấy mẫu theo lô"),
                ListDataItem(id: 3, name: "Lấy mẫu theo tỷ lệ")
            ]
        )
    }

    private func createFactoryData() -> ListItemProtocol {
        return SampleListItem(
            title: "Nhà máy",
            datas: [
                ListDataItem(id: 1, name: "Nhà máy Hà Nội"),
                ListDataItem(id: 2, name: "Nhà máy Hồ Chí Minh"),
                ListDataItem(id: 3, name: "Nhà máy Đà Nẵng")
            ]
        )
    }

    private func createProductionUnitData() -> ListItemProtocol {
        return SampleListItem(
            title: "Đơn vị sản xuất",
            datas: [
                ListDataItem(id: 1, name: "Đơn vị A"),
                ListDataItem(id: 2, name: "Đơn vị B"),
                ListDataItem(id: 3, name: "Đơn vị C")
            ]
        )
    }

    private func handleDropdownSelection(_ selectedItem: ListDataItem, for fieldType: InputFieldType) {
        switch fieldType {
        case .inspectionType:
            viewModel.inspectionType = selectedItem.name
        case .inspectionForm:
            viewModel.inspectionForm = selectedItem.name
        case .samplingMethod:
            viewModel.samplingMethod = selectedItem.name
        case .factory:
            viewModel.factory = selectedItem.name
        case .productionUnit:
            viewModel.productionUnit = selectedItem.name
        default:
            break
        }
    }
}

// MARK: - Sample List Item for Searchable Data
private struct SampleListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}

// MARK: - Preview
#Preview {
    CreateInspectionView()
}
