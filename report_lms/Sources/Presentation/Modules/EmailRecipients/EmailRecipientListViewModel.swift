//
//  EmailRecipientListViewModel.swift
//  report_lms
//

import Foundation

@MainActor
final class EmailRecipientListViewModel: ObservableObject {
    // MARK: - Published

    @Published var recipients: [FinalReportRecipient] = []

    // Add/Edit form
    @Published var isShowingForm = false
    @Published var editingRecipient: FinalReportRecipient?
    @Published var formName: String = ""
    @Published var formEmail: String = ""
    @Published var formIsDefault: Bool = false

    // Delete confirmation
    @Published var recipientPendingDelete: FinalReportRecipient?
    @Published var showDeleteAlert = false

    // MARK: - Computed

    /// Non-nil only once the user has typed something that fails email format validation.
    var emailValidationMessage: String? {
        let trimmed = formEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isValidEmail(trimmed) else { return nil }
        return LocalizationManager.shared.localize("emailRecipients.error.invalidEmail")
    }

    var canSave: Bool {
        let trimmedName = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = formEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && Self.isValidEmail(trimmedEmail)
    }

    // MARK: - Private

    private let store: EmailRecipientStore

    // MARK: - Init

    init(store: EmailRecipientStore = .shared) {
        self.store = store
    }

    // MARK: - Lifecycle

    func onAppear() {
        reload()
    }

    private func reload() {
        recipients = store.recipients
    }

    // MARK: - Form

    func startAdding() {
        editingRecipient = nil
        formName = ""
        formEmail = ""
        formIsDefault = false
        isShowingForm = true
    }

    func startEditing(_ recipient: FinalReportRecipient) {
        editingRecipient = recipient
        formName = recipient.name
        formEmail = recipient.email
        formIsDefault = recipient.isDefault
        isShowingForm = true
    }

    func saveForm() {
        guard canSave else { return }
        let trimmedName = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = formEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editing = editingRecipient {
            store.update(FinalReportRecipient(id: editing.id, name: trimmedName, email: trimmedEmail, isDefault: formIsDefault))
        } else {
            store.add(name: trimmedName, email: trimmedEmail, isDefault: formIsDefault)
        }
        reload()
        isShowingForm = false
    }

    // MARK: - Delete

    func requestDelete(_ recipient: FinalReportRecipient) {
        recipientPendingDelete = recipient
        showDeleteAlert = true
    }

    func confirmDelete() {
        guard let recipient = recipientPendingDelete else { return }
        store.delete(id: recipient.id)
        recipientPendingDelete = nil
        reload()
    }

    // MARK: - Validation

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
