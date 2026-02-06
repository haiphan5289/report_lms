//
//  WeekSection.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import Foundation

struct WeekSection: Identifiable, Equatable {
    let id: String
    let title: String
    let weekStartDate: Date
    let inspections: [Inspection]

    var itemCount: Int {
        inspections.count
    }

    init(id: String, title: String, weekStartDate: Date, inspections: [Inspection]) {
        self.id = id
        self.title = title
        self.weekStartDate = weekStartDate
        self.inspections = inspections
    }
}
