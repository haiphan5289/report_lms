//
//  SendEmailListView.swift
//  report_lms
//

import SwiftUI

// MARK: - SendEmailListView

struct SendEmailListView: View {

    // MARK: - Layout

    private enum Layout {
        static let heroHeight: CGFloat = 100
        static let rowCornerRadius: CGFloat = 14
        static let filterChipHeight: CGFloat = 34
        static let statusDotSize: CGFloat = 8
    }

    // MARK: - Properties

    @StateObject private var viewModel: SendEmailListViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var heroVisible = false
    @State private var listVisible = false
    @State private var filterVisible = false
    @State private var floatOffset: CGFloat = -5

    // MARK: - Init

    init(viewModel: SendEmailListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection
                filterBar
                content
            }
        }
        .navigationTitle("Lịch sử gửi Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.filteredTasks.isEmpty {
                    Button(role: .destructive) {
                        viewModel.showDeleteAllAlert = true
                    } label: {
                        if viewModel.isDeleting {
                            ProgressView().tint(.red)
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(viewModel.isDeleting)
                }
            }
        }
        .task {
            viewModel.onAppear()
            withAnimation(.easeOut(duration: 0.4)) { heroVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.35)) { filterVisible = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.4)) { listVisible = true }
        }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $viewModel.showDetail) {
            if let task = viewModel.selectedTask {
                SendEmailDetailSheet(task: task, isRetrying: viewModel.isRetrying) {
                    viewModel.retryTask()
                } onDelete: {
                    viewModel.requestDeleteTask(task)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Delete single confirmation
        .alert("Xóa email này?", isPresented: $viewModel.showDeleteSingleAlert) {
            Button("Xóa", role: .destructive) { viewModel.confirmDeleteTask() }
            Button("Huỷ", role: .cancel) { viewModel.taskPendingDelete = nil }
        } message: {
            if let task = viewModel.taskPendingDelete {
                Text("Xóa báo cáo #\(task.inspectionNumber) khỏi lịch sử?")
            }
        }
        // Delete all confirmation
        .alert(viewModel.deleteAllLabel, isPresented: $viewModel.showDeleteAllAlert) {
            Button("Xóa tất cả", role: .destructive) { viewModel.confirmDeleteAll() }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Hành động này không thể hoàn tác.")
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [LMSColor.primary, LMSColor.primary.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("\(viewModel.allTasks.count) báo cáo")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    statusPillsHero
                }
                Text("Toàn bộ email báo cáo đã được gửi")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(height: Layout.heroHeight)
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : -10)
        .animation(.easeOut(duration: 0.4), value: heroVisible)
    }

    private var statusPillsHero: some View {
        HStack(spacing: 6) {
            if viewModel.sentCount > 0 {
                heroPill(label: "\(viewModel.sentCount) gửi", color: .green)
            }
            if viewModel.failedCount > 0 {
                heroPill(label: "\(viewModel.failedCount) lỗi", color: .red)
            }
        }
    }

    private func heroPill(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.18)))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SendEmailListViewModel.FilterOption.allCases, id: \.self) { option in
                    filterChip(option)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .opacity(filterVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: filterVisible)
    }

    private func filterChip(_ option: SendEmailListViewModel.FilterOption) -> some View {
        let isSelected = viewModel.selectedFilter == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedFilter = option
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: option.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(option.label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .frame(height: Layout.filterChipHeight)
            .background(
                Capsule()
                    .fill(isSelected ? LMSColor.primary : Color(.systemGray6))
            )
            .shadow(color: isSelected ? LMSColor.primary.opacity(0.3) : .clear, radius: 6, y: 2)
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ZStack {
            if viewModel.isLoading {
                skeletonList
                    .transition(.opacity)
            } else if viewModel.filteredTasks.isEmpty {
                emptyState
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                taskList
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.35), value: viewModel.filteredTasks.isEmpty)
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    LMSEmailRowSkeleton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(viewModel.filteredTasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task, index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .opacity(listVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: listVisible)
    }

    private func taskRow(_ task: ReportDeliveryTask, index: Int) -> some View {
        Button {
            viewModel.selectTask(task)
        } label: {
            HStack(spacing: 14) {
                statusIcon(task.status)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(task.inspectionNumber)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        statusBadge(task.status)
                    }

                    Text(task.primaryRecipient)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if task.extraRecipientsCount > 0 {
                        Text("+\(task.extraRecipientsCount) người nhận")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(formatDate(task.sentAt ?? task.requestedAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cardSurface(cornerRadius: Layout.rowCornerRadius))
        }
        .buttonStyle(ScaleButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.requestDeleteTask(task)
            } label: {
                Label("Xóa", systemImage: "trash.fill")
            }
        }
        .opacity(listVisible ? 1 : 0)
        .offset(y: listVisible ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(Double(min(index, 6)) * 0.05), value: listVisible)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LMSColor.primary.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(LMSColor.primary.opacity(0.12), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.badge")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(LMSColor.primary.opacity(0.6))
            }
            .offset(y: floatOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    floatOffset = 5
                }
            }

            VStack(spacing: 8) {
                Text("Chưa có email nào được gửi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Danh sách sẽ xuất hiện khi\nbáo cáo được gửi đi.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(listVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: listVisible)
    }

    // MARK: - Helpers

    private func statusIcon(_ status: ReportDeliveryTaskStatus) -> some View {
        let (icon, color): (String, Color) = {
            switch status {
            case .sent:       return ("checkmark.circle.fill", .green)
            case .failed:     return ("xmark.circle.fill", .red)
            case .processing: return ("arrow.triangle.2.circlepath", LMSColor.primary)
            case .queued:     return ("clock.fill", .orange)
            }
        }()

        return ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 42, height: 42)
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .symbolEffect(.bounce, value: status == .processing)
        }
    }

    private func statusBadge(_ status: ReportDeliveryTaskStatus) -> some View {
        let color: Color = {
            switch status {
            case .sent:       return .green
            case .failed:     return .red
            case .processing: return LMSColor.primary
            case .queued:     return .orange
            }
        }()

        return Text(status.displayLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    /// Light: soft shadow. Dark: thin separator border (shadow is invisible on dark surfaces).
    private func cardSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return shape
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 8, x: 0, y: 3
            )
            .overlay(
                shape.stroke(
                    colorScheme == .dark ? Color(.separator).opacity(0.5) : .clear,
                    lineWidth: 0.5
                )
            )
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - SendEmailDetailSheet

struct SendEmailDetailSheet: View {
    let task: ReportDeliveryTask
    let isRetrying: Bool
    let onRetry: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentVisible = false
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: statusGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(task.inspectionNumber)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text(task.status.displayLabel)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(height: 110)
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: contentVisible)

            // Body
            ScrollView {
                VStack(spacing: 0) {
                    infoSection
                    recipientSection
                    if let errorMsg = task.errorMessage, task.status == .failed {
                        errorSection(errorMsg)
                    }
                }
                .padding(.bottom, task.status == .failed ? 100 : 32)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                if task.status == .failed {
                    VStack(spacing: 10) {
                        retryButton
                        deleteButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                } else {
                    deleteButton
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { contentVisible = true }
        }
        .alert("Xóa email này?", isPresented: $showDeleteAlert) {
            Button("Xóa", role: .destructive) { onDelete() }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Xóa báo cáo #\(task.inspectionNumber) khỏi lịch sử?")
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        VStack(spacing: 1) {
            detailRow(icon: "location", label: "Địa điểm", value: task.location.isEmpty ? "—" : task.location)
            detailRow(icon: "person", label: "Yêu cầu bởi", value: task.requestedBy.isEmpty ? "—" : task.requestedBy)
            detailRow(icon: "clock", label: "Thời gian yêu cầu", value: formatDate(task.requestedAt))
            if let sentAt = task.sentAt {
                detailRow(icon: "checkmark.circle", label: "Đã gửi lúc", value: formatDate(sentAt))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? Color(.separator).opacity(0.4) : .clear, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(0.05), value: contentVisible)
    }

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 16)
                Text("Người nhận (\(task.recipientEmails.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 1) {
                ForEach(task.recipientEmails, id: \.self) { email in
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme == .dark ? Color(.separator).opacity(0.4) : .clear, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(0.1), value: contentVisible)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3, height: 16)
                Text("Chi tiết lỗi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.red.opacity(0.85))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.15), lineWidth: 1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.15), value: contentVisible)
    }

    private var retryButton: some View {
        Button(action: onRetry) {
            HStack(spacing: 8) {
                if isRetrying {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isRetrying ? "Đang gửi lại..." : "Gửi lại email")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isRetrying ? Color.secondary : LMSColor.primary)
                    .shadow(color: LMSColor.primary.opacity(isRetrying ? 0 : 0.3), radius: 10, y: 4)
            )
            .scaleEffect(isRetrying ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRetrying)
        }
        .disabled(isRetrying)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.2), value: contentVisible)
    }

    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                Text("Xóa email này")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
            )
            .scaleEffect(1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.25), value: contentVisible)
    }

    // MARK: - Helpers

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(Divider().padding(.leading, 46), alignment: .bottom)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private var statusGradient: [Color] {
        switch task.status {
        case .sent:       return [Color.green.opacity(0.85), Color.green.opacity(0.6)]
        case .failed:     return [Color.red.opacity(0.85), Color.red.opacity(0.6)]
        case .processing: return [LMSColor.primary, LMSColor.primary.opacity(0.75)]
        case .queued:     return [Color.orange.opacity(0.85), Color.orange.opacity(0.6)]
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .sent:       return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        case .queued:     return "clock.fill"
        }
    }
}

// MARK: - LMSDeleteConfirmOverlay

private struct LMSDeleteConfirmOverlay: View {
    let icon: String
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                Divider()

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Huỷ")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    Divider().frame(height: 52)
                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, 44)
            .scaleEffect(appeared ? 1.0 : 0.82)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - LMSEmailRowSkeleton (matches real taskRow shape)

private struct LMSEmailRowSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            LMSSkeleton()
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    LMSSkeleton()
                        .frame(width: 110, height: 14)
                        .clipShape(Capsule())
                    Spacer()
                    LMSSkeleton()
                        .frame(width: 56, height: 20)
                        .clipShape(Capsule())
                }
                LMSSkeleton()
                    .frame(width: 180, height: 12)
                    .clipShape(Capsule())
                LMSSkeleton()
                    .frame(width: 90, height: 10)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                    radius: 6, x: 0, y: 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            colorScheme == .dark ? Color(.separator).opacity(0.5) : .clear,
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Preview

#Preview("Send Email List — Light") {
    NavigationStack {
        SendEmailListView(
            viewModel: SendEmailListViewModel(
                queueService: Container.shared.resolve(ReportDeliveryQueueService.self)!
            )
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Send Email List — Dark") {
    NavigationStack {
        SendEmailListView(
            viewModel: SendEmailListViewModel(
                queueService: Container.shared.resolve(ReportDeliveryQueueService.self)!
            )
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Detail Sheet — Failed (Dark)") {
    SendEmailDetailSheet(
        task: ReportDeliveryTask(
            id: "task_001",
            inspectionId: "INS-001",
            inspectionNumber: "INS-20260606-001",
            recipientEmails: ["manager@company.com", "qa@company.com"],
            location: "Hà Nội, Việt Nam",
            requestedBy: "hai.phan@chotot.vn",
            finalStatus: "accepted",
            summaryComments: "",
            status: .failed,
            requestedAt: Date(),
            sentAt: nil,
            errorMessage: "SMTP authentication failed: Invalid credentials provided."
        ),
        isRetrying: false,
        onRetry: {},
        onDelete: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Detail Sheet — Sent (Light)") {
    SendEmailDetailSheet(
        task: ReportDeliveryTask(
            id: "task_002",
            inspectionId: "INS-002",
            inspectionNumber: "INS-20260606-002",
            recipientEmails: ["client@company.com"],
            location: "TP. Hồ Chí Minh",
            requestedBy: "hai.phan@chotot.vn",
            finalStatus: "accepted",
            summaryComments: "",
            status: .sent,
            requestedAt: Date(),
            sentAt: Date(),
            errorMessage: nil
        ),
        isRetrying: false,
        onRetry: {},
        onDelete: {}
    )
    .preferredColorScheme(.light)
}
