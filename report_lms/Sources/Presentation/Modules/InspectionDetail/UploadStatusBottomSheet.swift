//
//  UploadStatusBottomSheet.swift
//  report_lms
//

import SwiftUI

struct UploadStatusBottomSheet: View {
    let sessions: [FieldUploadSession]
    @Binding var isPresented: Bool

    @State private var headerVisible = false
    @State private var listVisible = false
    @State private var floatOffset: CGFloat = -5

    private enum Layout {
        static let cardSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 24
        static let emptyStateSpacing: CGFloat = 14
        static let emptyIconCircleSize: CGFloat = 84
        static let emptyIconSize: CGFloat = 46
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionScrollView
                }
            }
            .navigationTitle("Trạng thái tải ảnh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Text("Đóng")
                            .fontWeight(.semibold)
                            .foregroundColor(LMSColor.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            withAnimation(.easeOut(duration: 0.38)) { headerVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.35)) { listVisible = true }
        }
    }

    // MARK: - Session Scroll

    private var sessionScrollView: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                ForEach(sessions) { session in
                    SessionCard(session: session, listVisible: listVisible)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.topPadding)
            .padding(.bottom, Layout.bottomPadding)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 18)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Layout.emptyStateSpacing) {
            ZStack {
                Circle()
                    .fill(LMSColor.success.opacity(0.12))
                    .frame(width: Layout.emptyIconCircleSize, height: Layout.emptyIconCircleSize)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Layout.emptyIconSize))
                    .foregroundColor(LMSColor.success)
                    .offset(y: floatOffset)
            }
            LMSLabel("Tất cả ảnh đã được tải lên", style: .headline)
            LMSLabel("Kiểm tra sẵn sàng để hoàn tất", style: .callout, color: .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatOffset = 5
            }
        }
    }
}

// MARK: - Session Card

private struct SessionCard: View {
    let session: FieldUploadSession
    let listVisible: Bool

    private enum Layout {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 2
        static let headerHorizontalPadding: CGFloat = 14
        static let headerVerticalPadding: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 14
        static let rowVerticalPadding: CGFloat = 11
        static let accentLineWidth: CGFloat = 3
        static let accentLineHeight: CGFloat = 18
        static let accentLineCornerRadius: CGFloat = 2
        static let headerSpacing: CGFloat = 8
        static let badgeHorizontalPadding: CGFloat = 8
        static let badgeVerticalPadding: CGFloat = 3
        static let dividerLeadingPadding: CGFloat = 14
        static let dividerRowLeadingPadding: CGFloat = 70  // headerPadding + thumbnailSize + rowSpacing
    }

    private var doneCount: Int {
        session.items.filter {
            if case .done = $0.status { return true }
            return false
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            Divider()
                .padding(.leading, Layout.dividerLeadingPadding)

            ForEach(Array(session.items.enumerated()), id: \.element.id) { index, item in
                ImageUploadRow(item: item)
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .padding(.vertical, Layout.rowVerticalPadding)
                    .opacity(listVisible ? 1 : 0)
                    .offset(y: listVisible ? 0 : 12)
                    .animation(
                        .easeOut(duration: 0.35).delay(Double(min(index, 6)) * 0.07),
                        value: listVisible
                    )

                if index < session.items.count - 1 {
                    Divider()
                        .padding(.leading, Layout.dividerRowLeadingPadding)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: Color(.label).opacity(0.07), radius: Layout.shadowRadius, x: 0, y: Layout.shadowY)
    }

    private var sectionHeader: some View {
        HStack(spacing: Layout.headerSpacing) {
            RoundedRectangle(cornerRadius: Layout.accentLineCornerRadius)
                .fill(LMSColor.primary)
                .frame(width: Layout.accentLineWidth, height: Layout.accentLineHeight)

            Image(systemName: "folder.fill")
                .font(.caption.weight(.medium))
                .foregroundColor(LMSColor.primary)

            LMSLabel(session.fieldLabel, style: .subheadline, lineLimit: 1)

            Spacer()

            doneBadge
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.vertical, Layout.headerVerticalPadding)
    }

    @ViewBuilder
    private var doneBadge: some View {
        let total = session.items.count
        let isAllDone = doneCount == total
        let badgeColor: Color = isAllDone ? LMSColor.success : LMSColor.primary

        Text("\(doneCount)/\(total)")
            .font(.caption.weight(.semibold))
            .foregroundColor(badgeColor)
            .padding(.horizontal, Layout.badgeHorizontalPadding)
            .padding(.vertical, Layout.badgeVerticalPadding)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.12))
                    .overlay(Capsule().stroke(badgeColor.opacity(0.28), lineWidth: 1))
            )
            .animation(.easeInOut(duration: 0.3), value: doneCount)
    }
}

// MARK: - Image Upload Row

private struct ImageUploadRow: View {
    let item: ImageUploadItem

    private enum Layout {
        static let thumbnailSize: CGFloat = 44
        static let thumbnailCornerRadius: CGFloat = 8
        static let thumbnailBorderWidth: CGFloat = 0.5
        static let thumbnailPlaceholderIconSize: CGFloat = 16
        static let rowSpacing: CGFloat = 12
        static let contentSpacing: CGFloat = 5
        static let progressBarSpacing: CGFloat = 4
        static let statusIconSize: CGFloat = 20
        static let spinnerSize: CGFloat = 20
        static let spinnerScale: CGFloat = 0.78
    }

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            thumbnailView
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                LMSLabel("Ảnh \(item.imageIndex + 1)", style: .subheadline)
                progressContent
            }
            Spacer(minLength: 0)
            statusIcon
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: statusKey)
    }

    private var statusKey: String {
        switch item.status {
        case .pending:   return "pending"
        case .uploading: return "uploading"
        case .done:      return "done"
        case .failed:    return "failed"
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = item.thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                        .stroke(Color(.separator), lineWidth: Layout.thumbnailBorderWidth)
                )
        } else {
            RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(Color(.tertiaryLabel))
                        .font(.system(size: Layout.thumbnailPlaceholderIconSize))
                )
        }
    }

    @ViewBuilder
    private var progressContent: some View {
        switch item.status {
        case .pending:
            LMSLabel("Đang chờ...", style: .caption, color: .tertiary)

        case .uploading(let progress):
            VStack(alignment: .leading, spacing: Layout.progressBarSpacing) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(LMSColor.primary)
                    .animation(.easeOut(duration: 0.2), value: progress)
                HStack {
                    LMSLabel("Đang tải lên...", style: .caption2, color: .secondary)
                    Spacer()
                    // Keep as Text to support .contentTransition — LMSLabel does not expose this modifier
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(LMSColor.primary)
                        .contentTransition(.numericText())
                }
            }

        case .done:
            LMSLabel("Hoàn tất", style: .caption, color: .success)

        case .failed:
            LMSLabel("Thất bại — quay lại để chụp lại", style: .caption, color: .error)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(Color(.tertiaryLabel))
                .font(.system(size: Layout.statusIconSize))

        case .uploading:
            ProgressView()
                .scaleEffect(Layout.spinnerScale)
                .frame(width: Layout.spinnerSize, height: Layout.spinnerSize)
                .tint(LMSColor.primary)

        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(LMSColor.success)
                .font(.system(size: Layout.statusIconSize))

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(LMSColor.destructive)
                .font(.system(size: Layout.statusIconSize))
        }
    }
}
