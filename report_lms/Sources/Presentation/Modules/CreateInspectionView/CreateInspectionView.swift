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
            createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!,
            storageService: Container.shared.resolve(InspectionStorageServiceType.self)!
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
        .alert("Thành công", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.showSuccessAlert = false
            }
        } message: {
            Text("Đã tạo báo cáo kiểm tra thành công!")
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

    private func createFactoryData() -> ListItemProtocol {
        return SampleListItem(
            title: "Nhà máy",
            datas: [
                ListDataItem(id: 1, name: "Không có nhà máy nào"),
                ListDataItem(id: 2, name: "KAISER 1 FURNITURE INDUSTRY (VIETNAM) CO., LTD"),
                ListDataItem(id: 3, name: "KAISER 2 FURNITURE INDUSTRY (VIETNAM) CO., LTD"),
                ListDataItem(id: 4, name: "MANWAH"),
                ListDataItem(id: 5, name: "Qarma Supplier"),
                ListDataItem(id: 6, name: "1 - HILLSDALE"),
                ListDataItem(id: 7, name: "111 - CASANA FURNITURE COMPANY"),
                ListDataItem(id: 8, name: "12345 - Test supplier Furniture"),
                ListDataItem(id: 9, name: "128 - ELEMENTS INTERNATIONAL-MX"),
                ListDataItem(id: 10, name: "136 - MAGNUSSEN HOME"),
                ListDataItem(id: 11, name: "137 - HOMELEGANCE, INC"),
                ListDataItem(id: 12, name: "151 - A.R.T./VIVET INC"),
                ListDataItem(id: 13, name: "158 - GARDENART CO. LIMITED"),
                ListDataItem(id: 14, name: "163 - ASHLEY FURNITURE"),
                ListDataItem(id: 15, name: "172 - ANA GLOBAL INC"),
                ListDataItem(id: 16, name: "188 - PROGRESSIVE FURNITURE"),
                ListDataItem(id: 17, name: "198 - KLAUSSNER CASEGOODS"),
                ListDataItem(id: 18, name: "202 - UNIVERSAL FURNITURE"),
                ListDataItem(id: 19, name: "22 - RIVERS EDGE FURNITURE"),
                ListDataItem(id: 20, name: "233 - JOFRAN"),
                ListDataItem(id: 21, name: "234 - MAN WAH (MCO) LTD"),
                ListDataItem(id: 22, name: "245 - KUKA"),
                ListDataItem(id: 23, name: "246 - BERNHARDT"),
                ListDataItem(id: 24, name: "25 - STANDARD"),
                ListDataItem(id: 25, name: "258 - TREASURE GARDEN"),
                ListDataItem(id: 26, name: "262 - BOLIYA USA"),
                ListDataItem(id: 27, name: "265 - ZINUS"),
                ListDataItem(id: 28, name: "27 - HTL INTERNATIONAL"),
                ListDataItem(id: 29, name: "274 - NICELINK HONG KONG TRADE"),
                ListDataItem(id: 30, name: "289 - SAMSON INTERNATIONAL ENT."),
                ListDataItem(id: 31, name: "293 - FURNITURE VALUES INT'L"),
                ListDataItem(id: 32, name: "294 - BENCHMASTER FURNITURE"),
                ListDataItem(id: 33, name: "296 - COAST TO COAST"),
                ListDataItem(id: 34, name: "3 - IDEAITALIA"),
                ListDataItem(id: 35, name: "308 - LIVING STYLE (S) PTE. LTD"),
                ListDataItem(id: 36, name: "309 - SUNPAN IMPORTS"),
                ListDataItem(id: 37, name: "33 - LIFESTYLE ENTERPRISE"),
                ListDataItem(id: 38, name: "331 - SYNERGY HOME FURNISHINGS"),
                ListDataItem(id: 39, name: "336 - GUARD MASTER INC."),
                ListDataItem(id: 40, name: "341 - MERCANA ART DECOR INC"),
                ListDataItem(id: 41, name: "35 - DECORO"),
                ListDataItem(id: 42, name: "359 - FLEXSTEEL"),
                ListDataItem(id: 43, name: "361 - Simon Li"),
                ListDataItem(id: 44, name: "366 - IN-ROOM DESIGNS"),
                ListDataItem(id: 45, name: "372 - LIBERTY FURNITURE IND,INC"),
                ListDataItem(id: 46, name: "374 - CLASSIC CONCEPTS, INC"),
                ListDataItem(id: 47, name: "375 - AMITY HOME"),
                ListDataItem(id: 48, name: "382 - TENGO RATTAN CO., LTD"),
                ListDataItem(id: 49, name: "386 - JUMBO LEAD DEV LIMITED"),
                ListDataItem(id: 50, name: "387 - FINE HOME SOFA VN CO LTD"),
                ListDataItem(id: 51, name: "402 - FI FOLIO 21"),
                ListDataItem(id: 52, name: "407 - EMERALD HOME FURNISHING"),
                ListDataItem(id: 53, name: "413 - HAPPY LEATHER"),
                ListDataItem(id: 54, name: "419 - RIVERSIDE"),
                ListDataItem(id: 55, name: "421 - AMINI INNOVATION CORP"),
                ListDataItem(id: 56, name: "427 - ANJI WEIYU FURNITURE CO"),
                ListDataItem(id: 57, name: "461 - PRESTIGE INTL INVESTMENTS"),
                ListDataItem(id: 58, name: "469 - CRAMCO, INC"),
                ListDataItem(id: 59, name: "470 - KEVIN CHARLES"),
                ListDataItem(id: 60, name: "480 - MAJESTIC MIRROR AND FRAME"),
                ListDataItem(id: 61, name: "499 - AISHANG PLASTIC CO."),
                ListDataItem(id: 62, name: "500 - MOTO INNOVATION VIETNAM"),
                ListDataItem(id: 63, name: "509 - NEW CLASSIC HOME"),
                ListDataItem(id: 64, name: "511 - MODUS FURNITURE"),
                ListDataItem(id: 65, name: "512 - NCA DESIGNS"),
                ListDataItem(id: 66, name: "513 - SAGEBROOK HOME"),
                ListDataItem(id: 67, name: "514 - AUSTIN GROUP FURNITURE"),
                ListDataItem(id: 68, name: "515 - ANJI MINGDIAN FURNITURE"),
                ListDataItem(id: 69, name: "516 - HUIZHOU HUAYA"),
                ListDataItem(id: 70, name: "517 - ANCO COMPANY LIMITED"),
                ListDataItem(id: 71, name: "518 - HOBANG"),
                ListDataItem(id: 72, name: "521 - PJ FURNITURE"),
                ListDataItem(id: 73, name: "523 - RETURN GOLD INTERNATIONAL"),
                ListDataItem(id: 74, name: "531 - KUMI FURNITURE LTD"),
                ListDataItem(id: 75, name: "534 - ALLSTATE FLORAL, INC."),
                ListDataItem(id: 76, name: "535 - CHENYU ARTS (JIANGSU) CO."),
                ListDataItem(id: 77, name: "536 - UNITED FURNITURE"),
                ListDataItem(id: 78, name: "542 - SHARDA EXPORTS"),
                ListDataItem(id: 79, name: "544 - BEIJING TOP-JIA TRADE CO."),
                ListDataItem(id: 80, name: "545 - UNIGARDEN LIMITED"),
                ListDataItem(id: 81, name: "546 - TAIZHOU MOCRYSTAL CO"),
                ListDataItem(id: 82, name: "549 - BEIJING HOME INTERIORS"),
                ListDataItem(id: 83, name: "551 - ZHONGSHAN SCILLUME"),
                ListDataItem(id: 84, name: "553 - YAZHI POLYRESIN CRAFTS"),
                ListDataItem(id: 85, name: "558 - HOMEPOINT"),
                ListDataItem(id: 86, name: "562 - JIANGSU SIDEFU TEXTILE CO"),
                ListDataItem(id: 87, name: "565 - ABBYSON LIVING"),
                ListDataItem(id: 88, name: "570 - SUMITRA WOODCRAFT PVT LTD"),
                ListDataItem(id: 89, name: "571 - HOME INSIGHTS, LLC"),
                ListDataItem(id: 90, name: "576 - M DESIGNS"),
                ListDataItem(id: 91, name: "577 - DUC CHINH WOOD MANUFACTUR"),
                ListDataItem(id: 92, name: "578 - YIWU RICH PHOTO FRAME CO."),
                ListDataItem(id: 93, name: "579 - FUZHOU TERUIER HOUSEWARE"),
                ListDataItem(id: 94, name: "580 - CHAOZHOU SANHONG CERAMICS"),
                ListDataItem(id: 95, name: "581 - WHITE FEATHERS PTE LTD"),
                ListDataItem(id: 96, name: "584 - NIFLORAL HOME FASHION"),
                ListDataItem(id: 97, name: "585 - GLORY"),
                ListDataItem(id: 98, name: "587 - MAYCO (FUJIAN) GROUP LTD"),
                ListDataItem(id: 99, name: "591 - DOVETAIL FURNITURE"),
                ListDataItem(id: 100, name: "593 - JAVI HOME"),
                ListDataItem(id: 101, name: "597 - HEALTHCARE"),
                ListDataItem(id: 102, name: "598 - FEIZY DROP SHIP"),
                ListDataItem(id: 103, name: "599 - ZHONGSHAN RONGDE LIGHTING"),
                ListDataItem(id: 104, name: "600 - OTIPOTI"),
                ListDataItem(id: 105, name: "604 - MANOR & MEWS"),
                ListDataItem(id: 106, name: "606 - HOME GUARD"),
                ListDataItem(id: 107, name: "608 - ZOY HOME FURNISHING"),
                ListDataItem(id: 108, name: "611 - TRENDWORLD"),
                ListDataItem(id: 109, name: "612 - MECEN"),
                ListDataItem(id: 110, name: "616 - PALMETTO HOME LLC"),
                ListDataItem(id: 111, name: "619 - YONG SHEN"),
                ListDataItem(id: 112, name: "623 - REGENT FINE FURNITURE LTD"),
                ListDataItem(id: 113, name: "626 - KIMSTONE"),
                ListDataItem(id: 114, name: "627 - GARDENLINE FURNITURE"),
                ListDataItem(id: 115, name: "635 - FLYING WINGS"),
                ListDataItem(id: 116, name: "638 - PT. KARUNIA KASIH ABADI"),
                ListDataItem(id: 117, name: "645 - BEHOLD HOME"),
                ListDataItem(id: 118, name: "646 - HUIZHOU SUNSISTER ART CO."),
                ListDataItem(id: 119, name: "647 - SHENZHEN MULAN INDUSTRY"),
                ListDataItem(id: 120, name: "648 - MLILY USA, INC"),
                ListDataItem(id: 121, name: "649 - SCANDIC HOUSE"),
                ListDataItem(id: 122, name: "651 - UNIQUE FURNITURE"),
                ListDataItem(id: 123, name: "652 - XINJU FURNITURE"),
                ListDataItem(id: 124, name: "655 - COMPOSAD SRL"),
                ListDataItem(id: 125, name: "657 - CHINTALY IMPORTS"),
                ListDataItem(id: 126, name: "660 - VOGUE HOME FURNISHINGS"),
                ListDataItem(id: 127, name: "661 - DRAGON EYE HOLDINGS"),
                ListDataItem(id: 128, name: "663 - TORRES GROUP"),
                ListDataItem(id: 129, name: "664 - HAINING DELI FURNITURE CO"),
                ListDataItem(id: 130, name: "665 - TPM CONCRETE PRD TRADE CO"),
                ListDataItem(id: 131, name: "666 - NISCO (THAILAND) CO.,LTD."),
                ListDataItem(id: 132, name: "673 - NINGBO YONGDELI DISPLAY"),
                ListDataItem(id: 133, name: "675 - ZHONGSHAN YIFAN LTD."),
                ListDataItem(id: 134, name: "677 - QINGDAO VIKER ART CO,LTD"),
                ListDataItem(id: 135, name: "680 - SAUDER WOODWORKING CO"),
                ListDataItem(id: 136, name: "682 - IDEA ENTERPRISES LIMITED"),
                ListDataItem(id: 137, name: "684 - BEIJING SANTA SUN CO.,LTD"),
                ListDataItem(id: 138, name: "687 - JS FURNITURE CO. LTD"),
                ListDataItem(id: 139, name: "688 - H317 LOGISTICS LLC"),
                ListDataItem(id: 140, name: "690 - PRIMST INNOVATION CO.LTD"),
                ListDataItem(id: 141, name: "691 - TRUONG THANH FURNITURE CO"),
                ListDataItem(id: 142, name: "694 - APRICOT FURNISHINGS VN CO"),
                ListDataItem(id: 143, name: "695 - LANGFANG HOMETREE"),
                ListDataItem(id: 144, name: "696 - ALLIANCE VANTAGE"),
                ListDataItem(id: 145, name: "697 - EKESA"),
                ListDataItem(id: 146, name: "698 - MINGBO SMART HOME TECH"),
                ListDataItem(id: 147, name: "701 - HENGLIN HOME"),
                ListDataItem(id: 148, name: "704 - DONGGUAN DONGLI PLASTIC"),
                ListDataItem(id: 149, name: "705 - HAOMEI"),
                ListDataItem(id: 150, name: "707 - PT. SMART"),
                ListDataItem(id: 151, name: "708 - HOMMAX FURNITURE"),
                ListDataItem(id: 152, name: "709 - ROCKHILL CONSOLIDATOR"),
                ListDataItem(id: 153, name: "710 - PTS AMERICA INC"),
                ListDataItem(id: 154, name: "711 - GUANGDONG SACA PRCSN MANU"),
                ListDataItem(id: 155, name: "713 - GUANGDONG SHENGYILONG"),
                ListDataItem(id: 156, name: "716 - MINH TIEN TIMBER USA"),
                ListDataItem(id: 157, name: "72 - SAMUEL LAWRENCE"),
                ListDataItem(id: 158, name: "723 - MELLOW RIVER INC DBA HH2"),
                ListDataItem(id: 159, name: "724 - VIET MY DONG NAI"),
                ListDataItem(id: 160, name: "725 - SHIJIE HOME"),
                ListDataItem(id: 161, name: "728 - LAC GIA FURNITURE"),
                ListDataItem(id: 162, name: "742 - HAO SAM INDUSTRY CO., LTD"),
                ListDataItem(id: 163, name: "745 - JINZHENG FURNITURE"),
                ListDataItem(id: 164, name: "959 - ECOLOGY"),
                ListDataItem(id: 165, name: "966 - NATURAL TEKSTIL TICARPET")
            ]
        )
    }

    private func createProductionUnitData() -> ListItemProtocol {
        return SampleListItem(
            title: "Đơn vị sản xuất",
            datas: [
                ListDataItem(id: 1, name: "Không có đơn vị sản xuất"),
                ListDataItem(id: 2, name: "535 - MAYCO GROUP LTD"),
                ListDataItem(id: 3, name: "793 - ROCKHILL ASIA LTD"),
                ListDataItem(id: 4, name: "80 - VCARE CO. LIMITED"),
                ListDataItem(id: 5, name: "794 - ROCKHILL ASIA LTD"),
                ListDataItem(id: 6, name: "Han Do Tran - 452"),
                ListDataItem(id: 7, name: "452 - CHENYU ARTS (JIANGSU) CO")
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
