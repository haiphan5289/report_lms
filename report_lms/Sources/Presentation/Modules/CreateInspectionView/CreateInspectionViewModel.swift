//
//  CreateInspectionViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import Foundation

final class CreateInspectionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var productName: String = ""
    @Published var productCode: String = ""
    @Published var orderCode: String = ""
    @Published var inspectionType: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var createdInspection: Inspection?
    
    // MARK: - Private Properties
    private let createInspectionUseCase: CreateInspectionUseCase
    
    // MARK: - Initialization
    init(createInspectionUseCase: CreateInspectionUseCase) {
        self.createInspectionUseCase = createInspectionUseCase
    }
    
    // MARK: - Public Methods
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
        if productName.isEmpty {
            errorMessage = "Tên sản phẩm không được để trống"
            return false
        }
        if productCode.isEmpty {
            errorMessage = "Mã sản phẩm không được để trống"
            return false
        }
        if orderCode.isEmpty {
            errorMessage = "Mã đơn hàng không được để trống"
            return false
        }
        if inspectionType.isEmpty {
            errorMessage = "Loại kiểm tra không được để trống"
            return false
        }
        return true
    }
    
    func resetForm() {
        productName = ""
        productCode = ""
        orderCode = ""
        inspectionType = ""
        errorMessage = nil
        createdInspection = nil
    }
}
