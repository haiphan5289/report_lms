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
    let email: String

    init(id: String = UUID().uuidString, name: String, email: String = "") {
        self.id = id
        self.name = name
        self.email = email
    }

    // MARK: - Mock Data
    static let mockRecipients: [FinalReportRecipient] = [
        FinalReportRecipient(name: "Nguyễn Văn A", email: "a.nguyen@example.com"),
        FinalReportRecipient(name: "Trần Thị B", email: "b.tran@example.com"),
        FinalReportRecipient(name: "Lê Văn C", email: "c.le@example.com"),
        FinalReportRecipient(name: "Phạm Thị D", email: "d.pham@example.com"),
        FinalReportRecipient(name: "Hoàng Văn E", email: "e.hoang@example.com"),
        FinalReportRecipient(name: "Vũ Thị F", email: "f.vu@example.com"),
        FinalReportRecipient(name: "Đặng Văn G", email: "g.dang@example.com"),
        FinalReportRecipient(name: "Bùi Thị H", email: "h.bui@example.com")
    ]
}
