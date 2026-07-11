//
//  EmailRecipientListView.swift
//  report_lms
//

import SwiftUI

// MARK: - EmailRecipientListView

/// "Danh sách Email" — CRUD list of saved report recipients (local-only, `EmailRecipientStore`).
/// Presented as a bottom sheet from the Menu; consumed by FinalReport's recipient picker.
struct EmailRecipientListView: View {
    @StateObject private var viewModel = EmailRecipientListViewModel()
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recipients.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(localizationManager.localize("emailRecipients.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localize("common.done")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.startAdding()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.isShowingForm) {
            formSheet
        }
        .alert(
            localizationManager.localize("emailRecipients.delete.confirm"),
            isPresented: $viewModel.showDeleteAlert
        ) {
            Button(localizationManager.localize("common.cancel"), role: .cancel) {}
            Button(localizationManager.localize("emailRecipients.delete.confirm"), role: .destructive) {
                viewModel.confirmDelete()
            }
        } message: {
            if let recipient = viewModel.recipientPendingDelete {
                Text(recipient.name)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(viewModel.recipients) { recipient in
                Button {
                    viewModel.startEditing(recipient)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            LMSLabel(recipient.name, style: .body, color: .primary)
                            LMSLabel(recipient.email, style: .caption, color: .secondary)
                        }
                        if recipient.isDefault {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(LMSColor.warning)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(recipient)
                    } label: {
                        Label(localizationManager.localize("emailRecipients.delete.confirm"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 40))
                .foregroundColor(LMSColor.secondary)
            LMSLabel(
                localizationManager.localize("emailRecipients.empty.title"),
                style: .headline,
                alignment: .center
            )
            LMSLabel(
                localizationManager.localize("emailRecipients.empty.subtitle"),
                style: .subheadline,
                color: .secondary,
                alignment: .center
            )
            LMSButton(
                localizationManager.localize("emailRecipients.add.title"),
                icon: "plus"
            ) {
                viewModel.startAdding()
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add / Edit Form

    private var formSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LMSSectionContainer(title: localizationManager.localize("emailRecipients.field.name")) {
                        TextField(
                            localizationManager.localize("emailRecipients.field.name.placeholder"),
                            text: $viewModel.formName
                        )
                        .padding(12)
                        .background(LMSColor.backgroundSecondary)
                        .cornerRadius(8)
                        .textInputAutocapitalization(.words)
                    }

                    LMSSectionContainer(title: localizationManager.localize("emailRecipients.field.email")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(
                                localizationManager.localize("emailRecipients.field.email.placeholder"),
                                text: $viewModel.formEmail
                            )
                            .padding(12)
                            .background(LMSColor.backgroundSecondary)
                            .cornerRadius(8)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            if let message = viewModel.emailValidationMessage {
                                LMSLabel(message, style: .caption, color: .error)
                            }
                        }
                    }

                    LMSSectionContainer {
                        Toggle(isOn: $viewModel.formIsDefault) {
                            VStack(alignment: .leading, spacing: 2) {
                                LMSLabel(localizationManager.localize("emailRecipients.field.default"), style: .body)
                                LMSLabel(
                                    localizationManager.localize("emailRecipients.field.default.subtitle"),
                                    style: .caption,
                                    color: .secondary
                                )
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(
                viewModel.editingRecipient == nil
                    ? localizationManager.localize("emailRecipients.add.title")
                    : localizationManager.localize("emailRecipients.edit.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localize("common.cancel")) {
                        viewModel.isShowingForm = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localize("common.save")) {
                        viewModel.saveForm()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailRecipientListView()
        .environmentObject(LocalizationManager.shared)
}
