//
//  GroupInspectionsByWeekUseCase.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import Foundation

final class GroupInspectionsByWeekUseCase {

    init() {}

    func execute(_ inspections: [Inspection]) -> [WeekSection] {
        let calendar = Calendar.current
        let now = Date()

        // Group inspections by week
        let weekGroups = Dictionary(grouping: inspections) { inspection -> String in
            let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: inspection.createdAt)
            let nowComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)

            guard let inspectionWeek = components.weekOfYear,
                  let inspectionYear = components.yearForWeekOfYear,
                  let currentWeek = nowComponents.weekOfYear,
                  let currentYear = nowComponents.yearForWeekOfYear else {
                return "unknown"
            }

            // Same week and year
            if inspectionWeek == currentWeek && inspectionYear == currentYear {
                return "this_week"
            }

            // Calculate week difference
            let weeksDiff = (currentYear - inspectionYear) * 52 + (currentWeek - inspectionWeek)

            if weeksDiff == 1 {
                return "last_week"
            } else if weeksDiff > 1 {
                return "\(weeksDiff)_weeks_ago"
            }

            return "unknown"
        }

        // Create sections
        let sections = weekGroups.compactMap { key, inspectionList -> WeekSection? in
            guard key != "unknown", let firstInspection = inspectionList.first else {
                return nil
            }

            let weekStartDate = calendar.dateInterval(
                of: .weekOfYear,
                for: firstInspection.createdAt
            )?.start ?? firstInspection.createdAt
            let sortedInspections = inspectionList.sorted {
                $0.createdAt > $1.createdAt
            }
            let title = localizedWeekTitle(key, count: sortedInspections.count)

            return WeekSection(
                id: key,
                title: title,
                weekStartDate: weekStartDate,
                inspections: sortedInspections
            )
        }

        // Sort sections by date (newest first)
        return sections.sorted { $0.weekStartDate > $1.weekStartDate }
    }

    private func localizedWeekTitle(_ key: String, count: Int) -> String {
        switch key {
        case "this_week":
            return "TUẦN NÀY (\(count))"
        case "last_week":
            return "TUẦN TRƯỚC (\(count))"
        default:
            if let weeksAgo = key.components(separatedBy: "_").first, let weeks = Int(weeksAgo) {
                return "\(weeks) TUẦN TRƯỚC (\(count))"
            }
            return "TUẦN KHÁC (\(count))"
        }
    }
}
