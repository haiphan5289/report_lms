//
//  OrderDetailBottomSheet.swift
//  report_lms
//

import SwiftUI

struct OrderDetailBottomSheet: View {
    let inspection: Inspection

    @Environment(\.dismiss) private var dismiss

    // Progressive reveal
    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var pdfSectionVisible = false

    // Delivery task
    @State private var sentTask: ReportDeliveryTask? = nil
    @State private var isLoadingTask = true
    @State private var taskLoadError: String? = nil

    // PDF download
    @State private var isDownloadingPDF = false
    @State private var pdfData: Data? = nil
    @State private var showPDFPreview = false
    @State private var downloadError: String? = nil

    private let deliveryService = Container.shared.resolve(ReportDeliveryQueueService.self)!
    private let storageService  = Container.shared.resolve(FirebaseStorageService.self)!

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.35), value: headerVisible)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    Divider().padding(.horizontal, 16)

                    detailSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(0.1), value: contentVisible)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    Divider().padding(.horizontal, 16)

                    pdfSection
                        .opacity(pdfSectionVisible ? 1 : 0)
                        .offset(y: pdfSectionVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(0.2), value: pdfSectionVisible)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(Color(.systemBackground))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showPDFPreview) {
            if let data = pdfData {
                PDFPreviewView(
                    pdfData: data,
                    fileName: "Bao_cao_kiem_tra_\(inspection.inspectionNumber).pdf"
                )
            }
        }
        .task {
            withAnimation { headerVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation { contentVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation { pdfSectionVisible = true }
            await loadDeliveryTask()
        }
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                LMSLabel(
                    inspection.inspectionNumber.isEmpty ? "---" : inspection.inspectionNumber,
                    style: .title2
                )
                LMSLabel(inspection.companyName.isEmpty ? "---" : inspection.companyName, style: .subheadline, color: .secondary)
            }
            Spacer()
            StatusBadge(status: inspection.status)
        }
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailRow(icon: "shippingbox", label: "Sản phẩm") {
                VStack(alignment: .leading, spacing: 2) {
                    LMSLabel(inspection.productName.isEmpty ? "---" : inspection.productName, style: .body)
                    if !inspection.productCode.isEmpty {
                        LMSLabel(inspection.productCode, style: .caption, color: .secondary)
                    }
                }
            }

            DetailRow(icon: "number", label: "Mã đơn hàng") {
                LMSLabel(inspection.orderCode.isEmpty ? "---" : inspection.orderCode, style: .body)
            }

            DetailRow(icon: "mappin.and.ellipse", label: "Nhà máy") {
                LMSLabel(inspection.factory.isEmpty ? "---" : inspection.factory, style: .body)
            }

            DetailRow(icon: "checklist", label: "Loại kiểm tra") {
                LMSLabel(inspection.inspectionType.isEmpty ? "---" : inspection.inspectionType, style: .body)
            }

            DetailRow(icon: "number.square", label: "Số lượng") {
                LMSLabel(
                    inspection.quantity.isEmpty ? "---" : "\(inspection.quantity) \(inspection.productionUnit)",
                    style: .body
                )
            }

            DetailRow(icon: "calendar", label: "Ngày tạo") {
                LMSLabel(inspection.formattedDate, style: .body)
            }
        }
    }

    // MARK: - PDF Section

    @ViewBuilder
    private var pdfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LMSColor.textSecondary)
                LMSLabel("Báo cáo PDF", style: .headline)
            }

            if isLoadingTask {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    LMSLabel("Đang kiểm tra...", style: .caption, color: .secondary)
                }
                .padding(.top, 4)
            } else if let err = taskLoadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                    LMSLabel(err, style: .caption, color: .secondary)
                        .lineLimit(3)
                }
                .padding(.top, 4)
            } else if let task = sentTask {
                sentPDFRow(task: task)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.slash")
                        .foregroundColor(LMSColor.textTertiary)
                    LMSLabel("Chưa có báo cáo PDF nào được gửi", style: .caption, color: .secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func sentPDFRow(task: ReportDeliveryTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sent info
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 13))
                if let sentAt = task.sentAt {
                    LMSLabel("Đã gửi lúc \(formatDate(sentAt))", style: .caption, color: .secondary)
                }
            }

            // Recipients
            if !task.recipientEmails.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .foregroundColor(LMSColor.textTertiary)
                        .font(.system(size: 13))
                    LMSLabel(task.recipientEmails.joined(separator: ", "), style: .caption, color: .secondary)
                        .lineLimit(2)
                }
            }

            // View PDF button
            if task.pdfStoragePath != nil {
                LMSButton(
                    "Xem PDF",
                    icon: "eye",
                    variant: .primary,
                    size: .medium,
                    isLoading: $isDownloadingPDF
                ) {
                    Task { await downloadAndShowPDF(task: task) }
                }
                .frame(maxWidth: .infinity)

                if let err = downloadError {
                    LMSLabel(err, style: .caption, color: .custom(.red))
                        .padding(.top, 4)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.icloud")
                        .foregroundColor(LMSColor.textTertiary)
                        .font(.system(size: 13))
                    LMSLabel("PDF đang được xử lý trên server", style: .caption, color: .secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Helpers

    private func loadDeliveryTask() async {
        isLoadingTask = true
        taskLoadError = nil
        defer { isLoadingTask = false }
        do {
            sentTask = try await deliveryService.latestSentTask(for: inspection.id)
        } catch {
            taskLoadError = "Không thể tải thông tin: \(error.localizedDescription)"
        }
    }

    private func downloadAndShowPDF(task: ReportDeliveryTask) async {
        guard let path = task.pdfStoragePath else { return }
        isDownloadingPDF = true
        downloadError = nil
        defer { isDownloadingPDF = false }
        do {
            pdfData = try await storageService.downloadData(fromPath: path)
            showPDFPreview = true
        } catch {
            downloadError = "Không thể tải PDF: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Detail Row

private struct DetailRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(LMSColor.textSecondary)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                LMSLabel(label, style: .caption, color: .secondary)
                content()
            }
        }
    }
}

// MARK: - Preview

#Preview("With sent PDF") {
    Text("Tap me")
        .sheet(isPresented: .constant(true)) {
            OrderDetailBottomSheet(inspection: .mock())
        }
        .environmentObject(LocalizationManager.shared)
}
