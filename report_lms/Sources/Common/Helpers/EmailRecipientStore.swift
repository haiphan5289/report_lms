//
//  EmailRecipientStore.swift
//  report_lms
//

import Foundation

/// Local, on-device persistence for the user's saved report-recipient list ("Danh sách Email"),
/// used by the Menu CRUD screen and consumed by FinalReport's recipient picker.
///
/// Not synced to Firestore — each device/install has its own list.
/// Thread safety: `UserDefaults` is thread-safe; all methods are safe to call from any context.
final class EmailRecipientStore {
    static let shared = EmailRecipientStore()

    private let defaults = UserDefaults.standard
    private let key = "savedEmailRecipients"

    private init() {}

    // MARK: - Read

    var recipients: [FinalReportRecipient] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FinalReportRecipient].self, from: data)) ?? []
    }

    // MARK: - Write

    @discardableResult
    func add(name: String, email: String, isDefault: Bool = false) -> FinalReportRecipient {
        let recipient = FinalReportRecipient(name: name, email: email, isDefault: isDefault)
        var current = recipients
        current.append(recipient)
        save(current)
        return recipient
    }

    func update(_ recipient: FinalReportRecipient) {
        var current = recipients
        guard let index = current.firstIndex(where: { $0.id == recipient.id }) else { return }
        current[index] = recipient
        save(current)
    }

    func delete(id: String) {
        save(recipients.filter { $0.id != id })
    }

    // MARK: - Private

    private func save(_ recipients: [FinalReportRecipient]) {
        guard let data = try? JSONEncoder().encode(recipients) else { return }
        defaults.set(data, forKey: key)
    }
}
