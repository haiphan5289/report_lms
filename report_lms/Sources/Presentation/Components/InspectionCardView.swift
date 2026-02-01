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
    let isLastIndex: Bool
    let onTap: () -> Void
    
    init(
        inspection: Inspection,
        isLastIndex: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.inspection = inspection
        self.isLastIndex = isLastIndex
        self.onTap = onTap
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with inspection number
            headerView
            
            Divider()
                .padding(.horizontal, 16)
            
            // Company and date info
            companyInfoView
            
            // Product info section
            productInfoView
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onTapGesture(perform: onTap)
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
    
    private var companyInfoView: some View {
        HStack(alignment: .top) {
            LMSLabel(inspection.companyName.isEmpty ? "---" : inspection.companyName, 
                    style: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    LMSLabel(inspection.productName, style: .body)
                    
                    HStack(spacing: 8) {
                        // Product code badge
                        HStack(spacing: 4) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.blue)
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
                            // Three dots menu
                            Button(action: {
                                // TODO: Implement menu action
                            }) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .rotationEffect(.degrees(90))
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
            companyName: "KUKA",
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
            companyName: "Very Long Company Name For Testing",
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
