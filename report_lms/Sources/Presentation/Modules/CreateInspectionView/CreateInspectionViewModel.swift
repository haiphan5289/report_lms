import Foundation
import SwiftUI

// MARK: - Input Field Type
enum InputFieldType: CaseIterable {
    case productName
    case productCode
    case orderCode
    case inspectionForm
    case inspectionType
    case samplingMethod
    case quantity
    case factory
    case productionUnit
}

// MARK: - Input Field Configuration
class InputField {
    let title: String
    let placeholder: String
    let type: ProductInfoInputType
    let text: Binding<String>
    var onDropdownTap: (() -> Void)?

    init(
        title: String,
        placeholder: String,
        type: ProductInfoInputType,
        text: Binding<String>,
        onDropdownTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self.type = type
        self.text = text
        self.onDropdownTap = onDropdownTap
    }
}

// MARK: - Input Field Type Extensions

@MainActor
final class CreateInspectionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var productName: String = "" {
        didSet {
            productNameError = validateField(productName, fieldName: "Tên sản phẩm")
        }
    }
    @Published var productCode: String = "" {
        didSet {
            productCodeError = validateField(productCode, fieldName: "Mã sản phẩm")
        }
    }
    @Published var orderCode: String = "" {
        didSet {
            orderCodeError = validateField(orderCode, fieldName: "Mã đơn hàng")
        }
    }
    @Published var inspectionType: String = "" {
        didSet {
            inspectionTypeError = validateField(inspectionType, fieldName: "Loại kiểm tra")
        }
    }
    @Published var inspectionForm: String = "" {
        didSet {
            inspectionFormError = validateField(inspectionForm, fieldName: "Biểu mẫu kiểm hàng")
        }
    }
    @Published var samplingMethod: String = "" {
        didSet {
            samplingMethodError = validateField(samplingMethod, fieldName: "Phương pháp lấy mẫu")
        }
    }
    @Published var quantity: String = "" {
        didSet {
            quantityError = validateField(quantity, fieldName: "Số lượng")
        }
    }
    @Published var factory: String = "" {
        didSet {
            factoryError = validateField(factory, fieldName: "Nhà máy")
        }
    }
    @Published var productionUnit: String = "" {
        didSet {
            productionUnitError = validateField(productionUnit, fieldName: "Đơn vị sản xuất")
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var createdInspection: Inspection?
    @Published var showSuccessAlert: Bool = false

    // MARK: - Field Error Messages
    @Published var productNameError: String?
    @Published var productCodeError: String?
    @Published var orderCodeError: String?
    @Published var inspectionFormError: String?
    @Published var inspectionTypeError: String?
    @Published var samplingMethodError: String?
    @Published var quantityError: String?
    @Published var factoryError: String?
    @Published var productionUnitError: String?

    // MARK: - Private Properties
    private let createInspectionUseCase: CreateInspectionUseCase
    private let storageService: InspectionStorageServiceType

    // MARK: - Initialization
    init(createInspectionUseCase: CreateInspectionUseCase, storageService: InspectionStorageServiceType) {
        self.createInspectionUseCase = createInspectionUseCase
        self.storageService = storageService
        // Initialize inputFields immediately
        inputFields = InputFieldType.allCases.map { type in
            InputField(
                title: type.title,
                placeholder: "",
                type: type.inputType,
                text: type.binding(for: self)
            )
        }
    }

    // MARK: - Input Fields Configuration
    private(set) var inputFields: [InputField] = []

    // MARK: - Field Errors Array (for dynamic access)
    var fieldErrors: [String?] {
        [
            productNameError,
            productCodeError,
            orderCodeError,
            inspectionFormError,
            inspectionTypeError,
            samplingMethodError,
            quantityError,
            factoryError,
            productionUnitError
        ]
    }

    // MARK: - Public Methods
    func createInspection() async {
        print("🟡 [CreateInspectionViewModel] createInspection() called")
        print("🟡 [CreateInspectionViewModel] Validating inputs...")

        guard validateInputs() else {
            print("🔴 [CreateInspectionViewModel] Validation failed!")
            print("🔴 [CreateInspectionViewModel] Field errors: \(fieldErrors)")
            return
        }

        print("🟡 [CreateInspectionViewModel] Validation passed")
        print("🟡 [CreateInspectionViewModel] Product: \(productName)")
        print("🟡 [CreateInspectionViewModel] Code: \(productCode)")
        print("🟡 [CreateInspectionViewModel] Order: \(orderCode)")

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            print("🟡 [CreateInspectionViewModel] isLoading set to false")
        }

        do {
            print("🟡 [CreateInspectionViewModel] Creating inspection with sections template...")
            
            // Parse quantity
            let orderQty = Int(quantity) ?? 0
            
            // Create inspection with sections template
            let inspection = Inspection(
                id: UUID().uuidString,
                inspectionNumber: "INS-\(Date().timeIntervalSince1970)",
                companyName: "",
                productName: productName,
                productCode: productCode,
                orderCode: orderCode,
                inspectionType: inspectionType,
                quantity: quantity,
                factory: factory,
                productionUnit: productionUnit,
                createdAt: Date(),
                inspectorId: nil,
                status: .plan,
                sections: Inspection.emptyTemplate(),
                orderQuantity: orderQty,
                actualCompletedQuantity: 0,
                aqlInspectionQuantity: 0,
                inspectedQuantity: 0
            )
            
            print("🟡 [CreateInspectionViewModel] Saving to FileManager...")
            try await storageService.saveInspection(inspection)
            
            print("✅ [CreateInspectionViewModel] Inspection saved successfully!")
            print("✅ [CreateInspectionViewModel] Inspection ID: \(inspection.id)")
            
            createdInspection = inspection
            showSuccessAlert = true
            
            print("✅ [CreateInspectionViewModel] createdInspection is now: \(String(describing: createdInspection))")
        } catch {
            print("🔴 [CreateInspectionViewModel] Error creating inspection: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Methods
    private func validateInputs() -> Bool {
        // Check if any required fields have errors
        return fieldErrors.allSatisfy { $0 == nil }
    }

    func resetForm() {
        productName = ""
        productCode = ""
        orderCode = ""
        inspectionForm = ""
        inspectionType = ""
        samplingMethod = ""
        quantity = ""
        factory = ""
        productionUnit = ""
        // Clear errors after setting empty strings
        productNameError = nil
        productCodeError = nil
        orderCodeError = nil
        inspectionFormError = nil
        inspectionTypeError = nil
        samplingMethodError = nil
        quantityError = nil
        factoryError = nil
        productionUnitError = nil
        errorMessage = nil
        createdInspection = nil
    }
}

// MARK: - Input Field Type Extensions
extension InputFieldType {
    var title: String {
        switch self {
        case .productName: return "Tên sản phẩm"
        case .productCode: return "Mã sản phẩm"
        case .orderCode: return "Mã đơn hàng"
        case .inspectionForm: return "Biểu mẫu kiểm hàng"
        case .inspectionType: return "Loại kiểm tra"
        case .samplingMethod: return "Phương pháp lấy mẫu"
        case .quantity: return "Số lượng"
        case .factory: return "Nhà máy"
        case .productionUnit: return "Đơn vị sản xuất"
        }
    }

    var inputType: ProductInfoInputType {
        switch self {
        case .productName, .productCode, .orderCode: return .required
        case .inspectionForm, .inspectionType, .samplingMethod, .factory, .productionUnit: return .dropdown
        case .quantity: return .quantity
        }
    }

    @MainActor
    func binding(for viewModel: CreateInspectionViewModel) -> Binding<String> {
        switch self {
        case .productName: return Binding(get: { viewModel.productName }, set: { viewModel.productName = $0 })
        case .productCode: return Binding(get: { viewModel.productCode }, set: { viewModel.productCode = $0 })
        case .orderCode: return Binding(get: { viewModel.orderCode }, set: { viewModel.orderCode = $0 })
        case .inspectionForm: return Binding(get: { viewModel.inspectionForm }, set: { viewModel.inspectionForm = $0 })
        case .inspectionType: return Binding(get: { viewModel.inspectionType }, set: { viewModel.inspectionType = $0 })
        case .samplingMethod: return Binding(get: { viewModel.samplingMethod }, set: { viewModel.samplingMethod = $0 })
        case .quantity: return Binding(get: { viewModel.quantity }, set: { viewModel.quantity = $0 })
        case .factory: return Binding(get: { viewModel.factory }, set: { viewModel.factory = $0 })
        case .productionUnit: return Binding(get: { viewModel.productionUnit }, set: { viewModel.productionUnit = $0 })
        }
    }

    @MainActor
    func errorMessage(for viewModel: CreateInspectionViewModel) -> String? {
        switch self {
        case .productName: return viewModel.productNameError
        case .productCode: return viewModel.productCodeError
        case .orderCode: return viewModel.orderCodeError
        case .inspectionForm: return viewModel.inspectionFormError
        case .inspectionType: return viewModel.inspectionTypeError
        case .samplingMethod: return viewModel.samplingMethodError
        case .quantity: return viewModel.quantityError
        case .factory: return viewModel.factoryError
        case .productionUnit: return viewModel.productionUnitError
        }
    }
}

// MARK: - Field Validation
private extension CreateInspectionViewModel {
    func validateField(_ value: String, fieldName: String) -> String? {
        return value.isEmpty ? "\(fieldName) không được để trống" : nil
    }
}
