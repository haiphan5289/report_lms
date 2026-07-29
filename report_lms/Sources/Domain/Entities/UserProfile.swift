//
//  UserProfile.swift
//  report_lms
//

import Foundation

enum UserRole: String, Codable {
    case owner
    case member
}

struct UserProfile: Identifiable, Equatable, Codable {
    let id: String
    let companyId: String
    let role: UserRole
    let displayName: String

    func toFirestoreData() throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dict ?? [:]
    }

    static func fromFirestore(_ data: [String: Any], id: String) throws -> UserProfile {
        var mutableData = data
        mutableData["id"] = id

        let decoder = JSONDecoder()
        let jsonData = try JSONSerialization.data(withJSONObject: mutableData)
        return try decoder.decode(UserProfile.self, from: jsonData)
    }
}
