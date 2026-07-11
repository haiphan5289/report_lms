//
//  FinalReportRecipient.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import Foundation

struct FinalReportRecipient: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let email: String
    /// When true, pre-checked in FinalReport's recipient picker (still toggleable per report).
    let isDefault: Bool

    init(id: String = UUID().uuidString, name: String, email: String = "", isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.email = email
        self.isDefault = isDefault
    }

    // MARK: - Codable

    // Manual init(from:)/encode(to:) so recipients saved before `isDefault` existed
    // still decode from UserDefaults instead of silently disappearing (defaults to false).
    private enum CodingKeys: String, CodingKey {
        case id, name, email, isDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(isDefault, forKey: .isDefault)
    }
}
