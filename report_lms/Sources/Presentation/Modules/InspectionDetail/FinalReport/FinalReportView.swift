//
//  FinalReportView.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import SwiftUI

struct FinalReportView: View {
    // MARK: - Constants
    private enum Layout {
        static let sectionSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 12
    }

    // MARK: - Properties
    @StateObject private var viewModel: FinalReportViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var inspectionDetailVM: InspectionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Animation
    @State private var contentVisible = false

    // MARK: - Initialization
    init(
        inspection: Inspection?,
        capturedPhotos: [String: [InspectionImage]]
    ) {
        _viewModel = StateObject(wrappedValue: FinalReportViewModel(
            inspection: inspection,
            capturedPhotos: capturedPhotos
        ))
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                LMSColor.backgroundGrouped
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: Layout.sectionSpacing) {
                        quantitiesSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35), value: contentVisible)
                        statusSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.08), value: contentVisible)
                        locationSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.16), value: contentVisible)
                        summarySection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.24), value: contentVisible)
                        notificationSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.32), value: contentVisible)
                        emailSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.38), value: contentVisible)
                        actionButtonsSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.40), value: contentVisible)
                        savePhotosSection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.44), value: contentVisible)
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical, Layout.verticalPadding)
                }
            }
            .navigationTitle(localizationManager.localize("finalReport.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(LMSColor.textPrimary)
                }
            )
            .task {
                withAnimation(.easeOut(duration: 0.35)) { contentVisible = true }
            }
        }
        .sheet(isPresented: $inspectionDetailVM.showUploadStatusSheet) {
            UploadStatusBottomSheet(
                sessions: inspectionDetailVM.uploadSessions,
                isPresented: $inspectionDetailVM.showUploadStatusSheet
            )
        }
        .sheet(isPresented: $viewModel.isShowingRecipientsPicker) {
            recipientsPickerView
        }
        .sheet(isPresented: $viewModel.isShowingMailComposer) {
            if let pdfData = viewModel.pdfData {
                MailComposerView(
                    pdfData: pdfData,
                    inspectionNumber: viewModel.inspection?.inspectionNumber ?? "",
                    recipientEmail: viewModel.recipientEmail.isEmpty ? nil : viewModel.recipientEmail,
                    onComplete: { result in
                        if result == .sent {
                            Task { await viewModel.handleEmailSent() }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingPDFPreview) {
            if let pdfData = viewModel.pdfData {
                PDFPreviewView(
                    pdfData: pdfData,
                    fileName: "Bao_cao_kiem_tra_\(viewModel.inspection?.inspectionNumber ?? "").pdf"
                )
            }
        }
        .overlay {
            if viewModel.isSavingPhotos {
                LMSLoadingOverlay(message: localizationManager.localize("finalReport.loading.savePhotos"), style: .dark)
            }
        }
        .overlay {
            if viewModel.showEmailQueuedAlert {
                SuccessConfirmationView(
                    title: localizationManager.localize("finalReport.queue.title"),
                    message: localizationManager.localize("finalReport.queue.message"),
                    confirmTitle: localizationManager.localize("common.ok")
                ) {
                    viewModel.showEmailQueuedAlert = false
                }
            }

            if viewModel.showEmailSuccessAlert {
                SuccessConfirmationView(
                    title: localizationManager.localize("finalReport.success.email.title"),
                    message: localizationManager.localize("finalReport.success.email.message"),
                    confirmTitle: localizationManager.localize("common.ok")
                ) {
                    viewModel.showEmailSuccessAlert = false
                }
            }

            if viewModel.showPhotoSaveSuccess {
                SuccessConfirmationView(
                    title: localizationManager.localize("finalReport.success.save.title"),
                    message: localizationManager.localize("finalReport.success.save.message", viewModel.totalPhotosCount),
                    confirmTitle: localizationManager.localize("common.ok")
                ) {
                    viewModel.showPhotoSaveSuccess = false
                }
            }
        }
        .alert(localizationManager.localize("common.error"), isPresented: $viewModel.showErrorAlert) {
            Button(localizationManager.localize("common.ok")) { }
        } message: {
            if let error = viewModel.errorAlertMessage {
                Text(error)
            }
        }
        .alert(localizationManager.localize("finalReport.error.photoSave.title"), isPresented: $viewModel.showPhotoSaveError) {
            Button(localizationManager.localize("common.ok")) { }
        } message: {
            if let error = viewModel.photoSaveErrorMessage {
                Text(error)
            }
        }
        .alert(localizationManager.localize("finalReport.error.emailUnavailable.title"), isPresented: $viewModel.showMailUnavailableAlert) {
            Button(localizationManager.localize("common.ok")) { }
        } message: {
            Text(localizationManager.localize("finalReport.error.emailUnavailable.message"))
        }
    }

    // MARK: - Section Views

    private var quantitiesSection: some View {
        LMSSectionContainer(title: localizationManager.localize("finalReport.section.quantity")) {
            VStack(spacing: 8) {
                LMSInfoRow(
                    label: localizationManager.localize("finalReport.quantity.order"),
                    value: "\(viewModel.inspection?.orderQuantity ?? 0)"
                )
                LMSInfoRow(
                    label: localizationManager.localize("finalReport.quantity.actual"),
                    value: "\(viewModel.inspection?.actualCompletedQuantity ?? 0)"
                )
                LMSInfoRow(
                    label: localizationManager.localize("finalReport.quantity.aql"),
                    value: "\(viewModel.inspection?.aqlInspectionQuantity ?? 0)"
                )
                LMSInfoRow(
                    label: localizationManager.localize("finalReport.quantity.inspected"),
                    value: "\(viewModel.inspection?.inspectedQuantity ?? 0)"
                )
            }
        }
    }

    private var statusSection: some View {
        LMSSectionContainer(title: localizationManager.localize("finalReport.section.status")) {
            Picker(localizationManager.localize("finalReport.section.status"), selection: $viewModel.selectedStatus) {
                ForEach(FinalReportStatus.allCases, id: \.self) { status in
                    Label {
                        Text(status.displayName)
                    } icon: {
                        Image(systemName: status.iconName)
                    }
                    .tag(status)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(LMSColor.backgroundSecondary)
            .cornerRadius(8)
        }
    }

    private var locationSection: some View {
        LMSSectionContainer(title: localizationManager.localize("finalReport.section.location")) {
            TextField(localizationManager.localize("finalReport.location.placeholder"), text: $viewModel.location)
                .padding(12)
                .background(LMSColor.backgroundSecondary)
                .cornerRadius(8)
                .font(.system(size: 15))
        }
    }

    private var summarySection: some View {
        LMSSectionContainer(title: localizationManager.localize("finalReport.section.summary")) {
            TextEditor(text: $viewModel.summaryComments)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(LMSColor.backgroundSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }

    private var notificationSection: some View {
        LMSSectionContainer {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    viewModel.toggleNotificationSection()
                }) {
                    HStack {
                        LMSLabel("\(localizationManager.localize("finalReport.section.notification")) (\(viewModel.recipientsCount))", style: .headline)
                        Spacer()
                        Image(systemName: viewModel.isNotificationSectionExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(LMSColor.textSecondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)

                if viewModel.isNotificationSectionExpanded {
                    LMSLabel(
                        localizationManager.localize("finalReport.notification.info"),
                        style: .caption,
                        color: .secondary
                    )
                    .padding(.top, 4)

                    if !viewModel.selectedRecipients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.selectedRecipients) { recipient in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(LMSColor.primary)
                                    LMSLabel(recipient.name, style: .body, color: .primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    LMSButton(
                        localizationManager.localize("common.add"),
                        icon: "plus.circle.fill",
                        variant: .tertiary,
                        size: .medium,
                        isFullWidth: true
                    ) {
                        viewModel.isShowingRecipientsPicker = true
                    }
                }
            }
        }
    }

    private var emailSection: some View {
        LMSSectionContainer(title: localizationManager.localize("finalReport.section.email")) {
            TextField(
                localizationManager.localize("finalReport.email.placeholder"),
                text: $viewModel.recipientEmail
            )
            .padding(12)
            .background(LMSColor.backgroundSecondary)
            .cornerRadius(8)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
    }

    private var actionButtonsSection: some View {
        let isUploading = inspectionDetailVM.activeUploadCount > 0
        let uploadCount = inspectionDetailVM.totalUploadingImageCount

        return VStack(alignment: .leading, spacing: 12) {
            LMSLabel(localizationManager.localize("finalReport.section.endInspection"), style: .headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                ZStack {
                    LMSButton(
                        isUploading
                            ? "Đang tải ảnh (\(uploadCount))..."
                            : localizationManager.localize("finalReport.button.sendEmail"),
                        icon: isUploading ? "clock.arrow.circlepath" : (viewModel.isSendingToServer ? "clock.arrow.circlepath" : "paperplane.fill"),
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: $viewModel.isSendingToServer,
                        isDisabled: viewModel.isGeneratingPDF || viewModel.isSendingToServer
                    ) {
                        if isUploading {
                            inspectionDetailVM.showUploadStatusSheet = true
                            inspectionDetailVM.pendingEmailSend = true
                        } else {
                            Task { await viewModel.sendReport() }
                        }
                    }

                    if isUploading {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                inspectionDetailVM.showUploadStatusSheet = true
                                inspectionDetailVM.pendingEmailSend = true
                            }
                    }
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.25), value: isUploading)
        }
        .onChange(of: inspectionDetailVM.activeUploadCount) { _, count in
            guard count == 0, inspectionDetailVM.pendingEmailSend else { return }
            inspectionDetailVM.pendingEmailSend = false
            Task { await viewModel.sendReport() }
        }
    }

    private var savePhotosSection: some View {
        LMSButton(
            "\(localizationManager.localize("finalReport.button.savePhotos")) (\(viewModel.totalPhotosCount))",
            icon: "photo.on.rectangle.angled",
            variant: .secondary,
            size: .medium,
            isFullWidth: true,
            isDisabled: viewModel.isSavingPhotos || viewModel.totalPhotosCount == 0
        ) {
            Task {
                await viewModel.saveAllPhotosToLibrary()
            }
        }
    }

    private var recipientsPickerView: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableRecipients) { recipient in
                    Button(action: {
                        viewModel.toggleRecipient(recipient)
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(LMSColor.primary)
                                .font(.system(size: 24))
                            LMSLabel(recipient.name, style: .body, color: .primary)
                            Spacer()
                            if viewModel.isRecipientSelected(recipient) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(LMSColor.primary)
                                    .font(.system(size: 24))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(localizationManager.localize("finalReport.recipients.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localize("finalReport.recipients.done")) {
                        viewModel.isShowingRecipientsPicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    FinalReportView(
        inspection: Inspection.mock(inspectionId: "1", inspectionNumber: "001"),
        capturedPhotos: ["field1": [InspectionImage(image: UIImage(systemName: "photo")!)]]
    )
}
