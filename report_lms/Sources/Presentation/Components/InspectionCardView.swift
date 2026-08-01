//
//  InspectionCardView.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import SwiftUI

struct InspectionCardView: View {
    // MARK: - Properties
    let inspection: Inspection
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReset: (() -> Void)?

    @State private var showingMenu = false
    @State private var showingDeleteConfirm = false

    private var hasMenuActions: Bool { onDelete != nil || onReset != nil }

    init(
        inspection: Inspection,
        onTap: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.inspection = inspection
        self.onTap = onTap
        self.onDelete = onDelete
        self.onReset = onReset
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with inspection number
            headerView

            Divider()
                .padding(.horizontal, 16)

            // Date info
            dateInfoView

            // Product info section
            productInfoView
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: LMSColor.Shadow.medium, radius: 4, x: 0, y: 2)
        .if(onTap != nil) { view in
            view.onTapGesture(perform: onTap!)
        }
        .confirmationDialog("", isPresented: $showingMenu, titleVisibility: .hidden) {
            Button("Xoá", role: .destructive) {
                showingDeleteConfirm = true
            }
            Button("Cài đặt lại") {
                onReset?()
            }
            Button("Huỷ Bỏ", role: .cancel) {}
        }
        .alert("Xác nhận xoá", isPresented: $showingDeleteConfirm) {
            Button("Xoá", role: .destructive) {
                onDelete?()
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc muốn xoá kiểm tra này không?")
        }
    }

    // MARK: - Private Views
    private var headerView: some View {
        HStack {
            LMSLabel(inspection.inspectionNumber.isEmpty ? "---" : inspection.inspectionNumber,
                    style: .headline)
            Spacer()
        }
        .padding(16)
    }

    private var dateInfoView: some View {
        HStack {
            Spacer()
            LMSLabel(inspection.formattedDate,
                    style: .caption,
                    color: .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var productInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Download icon placeholder
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .frame(width: 80, height: 80)
                    .background(Color(.systemFill))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    LMSLabel(inspection.productName, style: .body)

                    HStack(spacing: 8) {
                        // Product code badge
                        HStack(spacing: 4) {
                            ZStack {
                                Rectangle()
                                    .fill(LMSColor.primary)
                                    .frame(width: 24, height: 24)

                                LMSLabel("SA", style: .caption, color: .primary)
                                    .font(.system(size: 10, weight: .bold))
                            }

                            LMSLabel(inspection.productCode,
                                    style: .body)
                        }

                        Spacer()

                        // Status
                        VStack(spacing: 16) {
                            if hasMenuActions {
                                Button(action: { showingMenu = true }, label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .rotationEffect(.degrees(90))
                                })
                            }
                            LMSLabel(inspection.status.displayName,
                                     style: .caption,
                                     color: .secondary)
                        }
                    }
                }

            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview
#Preview("Default") {
    InspectionCardView(
        inspection: Inspection(
            inspectionNumber: "001",
            productName: "Ghe",
            productCode: "001",
            orderCode: "ORD123",
            inspectionType: "Quality Check",
            quantity: "100",
            factory: "Factory A",
            productionUnit: "Unit 1",
            status: .plan
        ),
        onTap: {}
    )
    .padding()
}

#Preview("Long Name") {
    InspectionCardView(
        inspection: Inspection(
            inspectionNumber: "002",
            productName: "Product with a very long name",
            productCode: "PROD-12345",
            orderCode: "ORD456",
            inspectionType: "Full Inspection",
            quantity: "500",
            factory: "Factory B",
            productionUnit: "Unit 2",
            status: .inProgress
        ),
        onTap: {}
    )
    .padding()
}
