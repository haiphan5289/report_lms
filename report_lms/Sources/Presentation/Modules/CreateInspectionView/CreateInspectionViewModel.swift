import Foundation
import SwiftUI

// MARK: - Input Field Configuration
class InputField {
    let title: String
    let placeholder: String
    let type: ProductInfoInputType
    let text: Binding<String>
    var onDropdownTap: (() -> Void)? = nil
    
    init(title: String, placeholder: String, type: ProductInfoInputType, text: Binding<String>, onDropdownTap: (() -> Void)? = nil) {
        self.title = title
        self.placeholder = placeholder
        self.type = type
        self.text = text
        self.onDropdownTap = onDropdownTap
    }
}

final class CreateInspectionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var productName: String = "" {
        didSet {
            print("ViewModel - productName changed: \(productName)")
            if productName.isEmpty {
                productNameError = "Tên sản phẩm không được để trống"
            } else {
                productNameError = nil
            }
        }
    }
    @Published var productCode: String = "" {
        didSet {
            print("ViewModel - productCode changed: \(productCode)")
            if productCode.isEmpty {
                productCodeError = "Mã sản phẩm không được để trống"
            } else {
                productCodeError = nil
            }
        }
    }
    @Published var orderCode: String = "" {
        didSet {
            print("ViewModel - orderCode changed: \(orderCode)")
            if orderCode.isEmpty {
                orderCodeError = "Mã đơn hàng không được để trống"
            } else {
                orderCodeError = nil
            }
        }
    }
    @Published var inspectionType: String = "" {
        didSet {
            print("ViewModel - inspectionType changed: \(inspectionType)")
            if inspectionType.isEmpty {
                inspectionTypeError = "Loại kiểm tra không được để trống"
            } else {
                inspectionTypeError = nil
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var createdInspection: Inspection?
    
    // MARK: - Field Error Messages
    @Published var productNameError: String?
    @Published var productCodeError: String?
    @Published var orderCodeError: String?
    @Published var inspectionTypeError: String?
    
    // MARK: - Private Properties
    private let createInspectionUseCase: CreateInspectionUseCase
    
    // MARK: - Initialization
    init(createInspectionUseCase: CreateInspectionUseCase) {
        self.createInspectionUseCase = createInspectionUseCase
    }
    
    // MARK: - Input Fields Configuration
    lazy var inputFields: [InputField] = [
        InputField(
            title: "Tên sản phẩm",
            placeholder: "",
            type: .required,
            text: Binding(get: { self.productName }, set: { self.productName = $0 })
        ),
        InputField(
            title: "Mã sản phẩm",
            placeholder: "",
            type: .required,
            text: Binding(get: { self.productCode }, set: { self.productCode = $0 })
        ),
        InputField(
            title: "Mã đơn hàng",
            placeholder: "",
            type: .required,
            text: Binding(get: { self.orderCode }, set: { self.orderCode = $0 })
        ),
        InputField(
            title: "Loại kiểm tra",
            placeholder: "",
            type: .dropdown,
            text: Binding(get: { self.inspectionType }, set: { self.inspectionType = $0 })
        )
    ]
    
    // MARK: - Public Methods
    func configureDropdownTapHandler(_ handler: @escaping () -> Void) {
        // Find the inspection type field and set the dropdown tap handler
        if let index = inputFields.firstIndex(where: { $0.title == "Loại kiểm tra" }) {
            inputFields[index].onDropdownTap = handler
        }
    }
    
    func createInspection() async {
        guard validateInputs() else { return }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let inspection = try await createInspectionUseCase.execute(
                productName: productName,
                productCode: productCode,
                orderCode: orderCode,
                inspectionType: inspectionType
            )
            createdInspection = inspection
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func validateInputs() -> Bool {
        // Check if any required fields have errors
        return productNameError == nil && productCodeError == nil && orderCodeError == nil && inspectionTypeError == nil
    }
    
    func resetForm() {
        productName = ""
        productCode = ""
        orderCode = ""
        inspectionType = ""
        // Clear errors after setting empty strings
        productNameError = nil
        productCodeError = nil
        orderCodeError = nil
        inspectionTypeError = nil
        errorMessage = nil
        createdInspection = nil
    }
}
