//
//  CacheDebugOverlay.swift
//  report_lms
//
//  Debug panel: shows realtime cache + upload events for the active inspection field.
//  Presented as a bottom sheet from InspectionValidationView.
//

import SwiftUI

// MARK: - Debug toggle button (shown in nav bar in DEBUG builds)

struct CacheDebugButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "ladybug.fill")
                .foregroundColor(.orange)
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

// MARK: - Main overlay sheet

struct CacheDebugOverlay: View {
    let inspectionId: String
    let fieldId: String

    @StateObject private var logger = CacheDebugLogger.shared
    @State private var stats: (ram: Int, disk: Int) = (0, 0)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats strip
                statsStrip
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))

                Divider()

                // Event log
                if logger.entries.isEmpty {
                    Spacer()
                    Text("Không có sự kiện nào")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(logger.entries) { entry in
                                EventRow(entry: entry)
                                Divider().padding(.leading, 40)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cache Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xoá") { logger.clear() }
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            await refreshStats()
        }
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 16) {
            statChip(
                label: "RAM",
                value: "\(stats.ram)",
                color: .orange,
                icon: "memorychip"
            )
            statChip(
                label: "Disk",
                value: "\(stats.disk)",
                color: .blue,
                icon: "internaldrive"
            )
            statChip(
                label: "Pending",
                value: "\(PendingUploadStore.shared.getPendingFilePaths(inspectionId: inspectionId, fieldId: fieldId).count)",
                color: .red,
                icon: "arrow.up.circle"
            )
            Spacer()
            Button {
                Task { await refreshStats() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func statChip(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Private

    private func refreshStats() async {
        let s = await InspectionImageCacheActor.shared.stats(inspectionId: inspectionId, fieldId: fieldId)
        stats = s
    }
}

// MARK: - Event row

private struct EventRow: View {
    let entry: CacheDebugLogger.LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.event.emoji)
                .font(.system(size: 18))
                .frame(width: 28)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.event.label)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(entry.timestamp)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
    }

    private var rowBackground: Color {
        switch entry.event {
        case .diskWrite:     return Color.blue.opacity(0.04)
        case .diskHit:       return Color.blue.opacity(0.02)
        case .ramHit:        return Color.orange.opacity(0.04)
        case .pendingAdded:  return Color.purple.opacity(0.04)
        case .retryStarted:  return Color.yellow.opacity(0.06)
        case .uploadSuccess: return Color.green.opacity(0.06)
        case .evicted:       return Color.red.opacity(0.04)
        }
    }
}
