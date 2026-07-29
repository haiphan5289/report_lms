//
//  Company.swift
//  report_lms
//

import Foundation

struct Company: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let joinCode: String
    let ownerId: String
    let createdAt: Date

    func toFirestoreData() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dict ?? [:]
    }

    /// Parses `data` field-by-field with safe casts instead of round-tripping it through
    /// `JSONSerialization.data(withJSONObject:)`. That call raises an uncaught Objective-C
    /// exception (not a catchable Swift error) for any value that isn't a plain JSON type —
    /// e.g. a native Firestore `Timestamp`/`GeoPoint` — which would otherwise crash the app
    /// instead of surfacing as a normal decoding failure.
    static func fromFirestore(_ data: [String: Any], id: String) throws -> Company {
        guard let name = data["name"] as? String else {
            throw CompanyDecodingError.missingField("name")
        }
        guard let joinCode = data["joinCode"] as? String else {
            throw CompanyDecodingError.missingField("joinCode")
        }
        guard let ownerId = data["ownerId"] as? String else {
            throw CompanyDecodingError.missingField("ownerId")
        }
        guard let createdAtString = data["createdAt"] as? String,
              let createdAt = Self.parseISO8601(createdAtString) else {
            throw CompanyDecodingError.invalidField("createdAt")
        }

        return Company(id: id, name: name, joinCode: joinCode, ownerId: ownerId, createdAt: createdAt)
    }

    /// Companies created via the app (`JSONEncoder` + `.iso8601`) write `createdAt` without
    /// fractional seconds (`...T07:11:44Z`); companies backfilled by the Node.js migration
    /// script (`new Date().toISOString()`) always include milliseconds (`...T07:11:44.275Z`).
    /// `ISO8601DateFormatter`'s default options only accept the first form, so both are tried.
    private static func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }
}

enum CompanyDecodingError: LocalizedError {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Dữ liệu công ty thiếu trường \"\(field)\""
        case .invalidField(let field):
            return "Dữ liệu công ty có trường \"\(field)\" không đúng định dạng"
        }
    }
}
