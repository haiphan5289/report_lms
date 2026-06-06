//
//  ReportDeliveryTask.swift
//  report_lms
//

import Foundation

struct ReportDeliveryTask: Identifiable {
    let id: String
    let inspectionId: String
    let inspectionNumber: String
    let recipientEmails: [String]
    let location: String
    let requestedBy: String
    let finalStatus: String
    let summaryComments: String
    var status: ReportDeliveryTaskStatus
    let requestedAt: Date
    var sentAt: Date?
    var errorMessage: String?

    var primaryRecipient: String { recipientEmails.first ?? "" }
    var extraRecipientsCount: Int { max(0, recipientEmails.count - 1) }
}

enum ReportDeliveryTaskStatus: String, CaseIterable {
    case queued
    case processing
    case sent
    case failed

    var displayLabel: String {
        switch self {
        case .queued:      return "Đang chờ"
        case .processing:  return "Đang gửi"
        case .sent:        return "Đã gửi"
        case .failed:      return "Thất bại"
        }
    }

    var filterLabel: String {
        switch self {
        case .queued:      return "Chờ"
        case .processing:  return "Đang gửi"
        case .sent:        return "Đã gửi"
        case .failed:      return "Thất bại"
        }
    }
}
