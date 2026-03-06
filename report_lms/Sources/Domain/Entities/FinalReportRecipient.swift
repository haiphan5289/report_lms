//
//  FinalReportRecipient.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import Foundation

struct FinalReportRecipient: Identifiable, Equatable {
    let id: String
    let name: String
    
    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
    
    // MARK: - Mock Data
    static let mockRecipients: [FinalReportRecipient] = [
        FinalReportRecipient(name: "Nguyễn Văn A"),
        FinalReportRecipient(name: "Trần Thị B"),
        FinalReportRecipient(name: "Lê Văn C"),
        FinalReportRecipient(name: "Phạm Thị D"),
        FinalReportRecipient(name: "Hoàng Văn E"),
        FinalReportRecipient(name: "Vũ Thị F"),
        FinalReportRecipient(name: "Đặng Văn G"),
        FinalReportRecipient(name: "Bùi Thị H")
    ]
}
