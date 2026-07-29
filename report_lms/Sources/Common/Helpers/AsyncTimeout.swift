//
//  AsyncTimeout.swift
//  report_lms
//

import Foundation

struct AsyncTimeoutError: LocalizedError {
    var errorDescription: String? { "Yêu cầu quá thời gian chờ, vui lòng thử lại." }
}

/// Races `operation` against a `seconds`-long timer so a hung network/Firestore call
/// surfaces as a clear error instead of an indefinite hang.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AsyncTimeoutError()
        }
        guard let result = try await group.next() else {
            throw AsyncTimeoutError()
        }
        group.cancelAll()
        return result
    }
}
