//
//  ImageUploadItem.swift
//  report_lms
//

import UIKit

enum ImageUploadStatus: Equatable {
    case pending
    case uploading(progress: Double)
    case done
    case failed
}

struct ImageUploadItem: Identifiable {
    let id: String
    let imageIndex: Int
    let thumbnail: UIImage?
    var status: ImageUploadStatus
}

struct FieldUploadSession: Identifiable {
    let id: String          // fieldId
    let fieldLabel: String
    var items: [ImageUploadItem]

    var isComplete: Bool {
        items.allSatisfy { $0.status == .done || $0.status == .failed }
    }
}
