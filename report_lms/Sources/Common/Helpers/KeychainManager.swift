//
//  KeychainManager.swift
//  report_lms
//
//  Created by AI on February 6, 2026.
//

import Foundation
import Security

/// A manager class for securely storing and retrieving authentication tokens using iOS Keychain Services
final class KeychainManager {
    // MARK: - Constants
    private static let authTokenKey = "authToken"
    private static let serviceName = "com.reportlms.auth"

    // MARK: - Public Methods

    /// Saves the authentication token to Keychain after successful login
    /// - Parameter token: The authentication token to store
    static func saveAuthToken(_ token: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: authTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing token first
        SecItemDelete(query as CFDictionary)

        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving auth token to Keychain: \(status)")
        }
    }

    /// Retrieves the authentication token from Keychain
    /// - Returns: The stored authentication token, or nil if not found
    static func getAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: authTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }

        return nil
    }

    /// Removes the authentication token from Keychain on logout
    static func deleteAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: authTokenKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting auth token from Keychain: \(status)")
        }
    }

    /// Checks if an authentication token exists in Keychain
    /// - Returns: True if token exists, false otherwise
    static func hasAuthToken() -> Bool {
        return getAuthToken() != nil
    }
}