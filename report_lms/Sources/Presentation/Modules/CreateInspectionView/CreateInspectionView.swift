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
    @State private var formVisible = false
    @State private var buttonVisible = false

    var onInspectionCreated: ((Inspection) -> Void)?

    // MARK: - Initialization
    init(viewModel: CreateInspectionViewModel? = nil, onInspectionCreated: ((Inspection) -> Void)? = nil) {
        let viewModel = viewModel ?? CreateInspectionViewModel(
            createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!,
            storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
            companyId: Container.shared.resolve(UserManager.self)?.companyId ?? ""
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
            .opacity(formVisible ? 1 : 0)
            .offset(y: formVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.4), value: formVisible)
            createButtonSection
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 12)
                .animation(.easeOut(duration: 0.35), value: buttonVisible)
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
        .task {
            withAnimation(.easeOut(duration: 0.4)) { formVisible = true }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.35)) { buttonVisible = true }
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
        default:
            // These fields don't have dropdown data
            return SampleListItem(title: "", datas: [])
        }
    }

    private func createInspectionTypeData() -> ListItemProtocol {
        return SampleListItem(
            title: "Loại kiểm tra",
            datas: [
                ListDataItem(id: 1, name: "Sample"),
                ListDataItem(id: 2, name: "Pre-Production"),
                ListDataItem(id: 3, name: "Inline"),
                ListDataItem(id: 4, name: "Final"),
                ListDataItem(id: 5, name: "Warehouse"),
                ListDataItem(id: 6, name: "Gemba")
            ]
        )
    }

    private func createInspectionFormData() -> ListItemProtocol {
        return SampleListItem(
            title: "Biểu mẫu kiểm hàng",
            datas: [
                ListDataItem(id: 1, name: "PIER CHECKLIST"),
                ListDataItem(id: 2, name: "PILLOW CHECKLIST"),
                ListDataItem(id: 3, name: "PRE-PRODUCTION SAMPLE CHECKLIST"),
                ListDataItem(id: 4, name: "RATTAN & BANANA LEAF FURNITURE"),
                ListDataItem(id: 5, name: "RUG CHECKLIST"),
                ListDataItem(id: 6, name: "SAMPLE REVIEW CHECKLIST"),
                ListDataItem(id: 7, name: "SIDEBOARD CHECKLIST"),
                ListDataItem(id: 8, name: "SOFA TABLE CHECKLIST"),
                ListDataItem(id: 9, name: "TABLETOP DECORATION & VASE & LANTERN CHECKLIST"),
                ListDataItem(id: 10, name: "THROW CHECKLIST"),
                ListDataItem(id: 11, name: "TV STAND CHECKLIST"),
                ListDataItem(id: 12, name: "WALL ART CHECKLIST"),
                ListDataItem(id: 13, name: "Warehouse - Qarma"),
                ListDataItem(id: 14, name: "KC-FOOTBOARD"),
                ListDataItem(id: 15, name: "KC-HEADBOARD"),
                ListDataItem(id: 16, name: "KC-INTERNAL AUDIT CUTTING"),
                ListDataItem(id: 17, name: "KC-INTERNAL FRAME"),
                ListDataItem(id: 18, name: "KC-POLY INSPECTION"),
                ListDataItem(id: 19, name: "KC-Quality Line Inspectors"),
                ListDataItem(id: 20, name: "KC-SIDERAIL"),
                ListDataItem(id: 21, name: "KC-Tailoring"),
                ListDataItem(id: 22, name: "LIGHTING CHECKLIST"),
                ListDataItem(id: 23, name: "MIRROR CHECKLIST"),
                ListDataItem(id: 24, name: "NIGHTSTAND CHECKLIST"),
                ListDataItem(id: 25, name: "CF-DINING BENCH CHECKLIST"),
                ListDataItem(id: 26, name: "CF-DINING CHAIR & SOFA CHECKLIST"),
                ListDataItem(id: 27, name: "CF-DINING TABLE CHECKLIST"),
                ListDataItem(id: 28, name: "CF-END TABLE CHECKLIST"),
                ListDataItem(id: 29, name: "CF-Generic Closet Packaging"),
                ListDataItem(id: 30, name: "CF-HUTCH CHECKLIST"),
                ListDataItem(id: 31, name: "CF-MIRROR CHECKLIST"),
                ListDataItem(id: 32, name: "CF-NIGHTSTAND CHECKLIST"),
                ListDataItem(id: 33, name: "CF-PIER CHECKLIST"),
                ListDataItem(id: 34, name: "CF-Scope - Color Variance Checklist"),
                ListDataItem(id: 35, name: "CF-Scope Generic Checklist"),
                ListDataItem(id: 36, name: "CF-Scope Mold Checklist"),
                ListDataItem(id: 37, name: "CF-SOFA TABLE CHECKLIST"),
                ListDataItem(id: 38, name: "CF-TABLETOP DECORATION & VASE & LANTERN CHECKLIST"),
                ListDataItem(id: 39, name: "CF-TV STAND CHECKLIST"),
                ListDataItem(id: 40, name: "CF-WALL ART"),
                ListDataItem(id: 41, name: "CHEST CHECKLIST"),
                ListDataItem(id: 42, name: "COFFEE TABLE CHECKLIST"),
                ListDataItem(id: 43, name: "CONSOLE TABLE CHECKLIST"),
                ListDataItem(id: 44, name: "DESK CHECKLIST"),
                ListDataItem(id: 45, name: "DINING BENCH CHECKLIST"),
                ListDataItem(id: 46, name: "DINING CHAIR & SOFA CHECKLIST"),
                ListDataItem(id: 47, name: "DINING TABLE CHECKLIST"),
                ListDataItem(id: 48, name: "END TABLE CHECKLIST"),
                ListDataItem(id: 49, name: "FINAL CHECKLIST NEW"),
                ListDataItem(id: 50, name: "FINAL CHECKLIST UPHOLSTERY"),
                ListDataItem(id: 51, name: "Gardenart Fireplace Table Checklist"),
                ListDataItem(id: 52, name: "GENERAL TABLE CHECKLIST"),
                ListDataItem(id: 53, name: "GOLDEN SAMPLE CHECKLIST"),
                ListDataItem(id: 54, name: "GREENERY CHECKLIST"),
                ListDataItem(id: 55, name: "HUTCH CHECKLIST"),
                ListDataItem(id: 56, name: "KC - Internal Audit - Sewing"),
                ListDataItem(id: 57, name: "KC - Internal Inspection Shipping"),
                ListDataItem(id: 58, name: "KC - Off the Belt Finished Good - Upholstery - Quality Audit"),
                ListDataItem(id: 59, name: "KC Feather's Cushion/Back"),
                ListDataItem(id: 60, name: "KC THROW PILLOW"),
                ListDataItem(id: 61, name: "KC- INTERNAL FILLING DEPARTMENT"),
                ListDataItem(id: 62, name: "BASKET CHECKLIST"),
                ListDataItem(id: 63, name: "BED CHECKLIST"),
                ListDataItem(id: 64, name: "BOOKCASE CHECKLIST"),
                ListDataItem(id: 65, name: "BUFFET CHECKLIST"),
                ListDataItem(id: 66, name: "CABINET CHECKLIST (chest/sideboar/buffet/dresser)"),
                ListDataItem(id: 67, name: "CF Product Inspection"),
                ListDataItem(id: 68, name: "CF-BASKET CHECKLIST"),
                ListDataItem(id: 69, name: "CF-BED CHECKLIST"),
                ListDataItem(id: 70, name: "CF-BOOKCASE CHECKLIST"),
                ListDataItem(id: 71, name: "CF-CHEST CHECKLIST"),
                ListDataItem(id: 72, name: "CF-COFFEE TABLE CHECKLIST"),
                ListDataItem(id: 73, name: "CF-CONSOLE TABLE CHECKLIST"),
                ListDataItem(id: 74, name: "CF-DESK CHECKLIST")
            ]
        )
    }

    private func createSamplingMethodData() -> ListItemProtocol {
        return SampleListItem(
            title: "Phương pháp lấy mẫu",
            datas: [
                ListDataItem(id: 1, name: "Bỏ qua phương pháp lấy mẫu"),
                ListDataItem(id: 2, name: "100% inspection"),
                ListDataItem(id: 3, name: "AQL 2.5/4.0 Level I"),
                ListDataItem(id: 4, name: "AQL 2.5/4.0 Level II"),
                ListDataItem(id: 5, name: "AQL 2.5/4.0 Level S4")
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
