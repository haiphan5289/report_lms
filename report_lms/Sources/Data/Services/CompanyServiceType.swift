//
//  CompanyServiceType.swift
//  report_lms
//

import Foundation

protocol CompanyServiceType {
    /// Creates a new `Company` with a freshly generated unique join code and
    /// writes the caller as its `owner` in the `users/{uid}` profile document.
    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> Company

    /// Resolves `code` to a `Company` and writes the caller as a `member` in
    /// the `users/{uid}` profile document.
    func joinCompany(code: String, userId: String, displayName: String) async throws -> Company

    /// Fetches the `users/{uid}` profile document, or `nil` if the user hasn't
    /// completed company onboarding yet (e.g. mid-signup, or a pre-migration account).
    func fetchUserProfile(userId: String) async throws -> UserProfile?

    /// Fetches the `companies/{id}` document, e.g. to display its join code.
    func fetchCompany(id: String) async throws -> Company
}

enum CompanyError: LocalizedError {
    case invalidJoinCode
    case companyNotFound
    case codeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidJoinCode:
            return "Mã công ty không hợp lệ hoặc không tồn tại"
        case .companyNotFound:
            return "Không tìm thấy công ty"
        case .codeGenerationFailed:
            return "Không thể tạo mã công ty, vui lòng thử lại"
        }
    }
}
