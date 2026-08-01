//
//  ErrorItemUploadCoordinator.swift
//  report_lms
//

import UIKit
import OSLog

/// Owns the real persistence + upload work for one `SavedErrorItem` — writes local images to
/// `LocalImageStore` (Documents/, survives OS cache eviction), registers a
/// `PendingErrorUploadStore` entry, then calls `ErrorRepositoryType.saveErrorItem` with the
/// REAL image sources so photos actually reach Firebase Storage + Firestore.
///
/// Mirrors `FieldUploadCoordinator` / `PendingUploadRetryService` (InspectionValidation), but
/// scoped down: no RAM thumbnail cache, and no long-lived per-view ownership —
/// `ErrorHomeViewModel` is recreated on every tab switch, so an upload chain owned by it would
/// be lost mid-upload on tab switch. This is a singleton instead; the durability guarantee
/// against app kills comes from `PendingUploadRetryService` retrying at next launch, not from
/// this in-memory task chain.
///
/// `sessions` reuses `FieldUploadSession`/`ImageUploadItem` (the models `UploadStatusBottomSheet`
/// already renders for field images) so error-item uploads can be merged into the same sheet
/// with no changes to the sheet's UI code.
@MainActor
final class ErrorItemUploadCoordinator: ObservableObject {
    static let shared = ErrorItemUploadCoordinator()
    private init() {}

    private let logger = Logger(subsystem: "com.reportlms", category: "ErrorItemUploadCoordinator")
    private var tasks: [String: Task<Void, Never>] = [:]

    /// Number of error-item saves currently in flight (disk write + Storage upload + Firestore
    /// write). `FinalReportView` waits for this to reach 0 — alongside `InspectionDetailViewModel
    /// .activeUploadCount` for field images — before sending the report email. Mirrors
    /// `activeUploadCount`'s semantics exactly: decrements only after the Firestore write
    /// attempt finishes (success or failure), never right after the image upload — see
    /// `UploadStatusBottomSheet.md` § Bug B5 for why the earlier signal caused a missing-photo
    /// PDF for field images; the same race applies here if not guarded the same way.
    @Published private(set) var activeCount: Int = 0

    /// One session per error item currently uploading (or just finished) — merged into
    /// `UploadStatusBottomSheet`'s `sessions` list alongside field-image sessions.
    @Published private(set) var sessions: [FieldUploadSession] = []

    /// Images still `.pending`/`.uploading` across all error-item sessions — added to
    /// `InspectionDetailViewModel.totalUploadingImageCount` for the "Đang tải ảnh (N)..." label.
    var pendingImageCount: Int {
        sessions.reduce(0) { count, session in
            count + session.items.filter {
                if case .done = $0.status { return false }
                if case .failed = $0.status { return false }
                return true
            }.count
        }
    }

    /// Persists images to disk + registers pending metadata as the FIRST step, so
    /// `PendingUploadRetryService` can pick this item up even if the app is killed before the
    /// upload attempt below completes. Chains onto any in-flight save for the same item
    /// (serial) so a rapid re-edit can't race the previous save's Firestore write.
    func enqueue(
        item: SavedErrorItem,
        localImages: [UIImage],
        existingRemoteURLs: [String],
        inspectionId: String,
        errorRepository: ErrorRepositoryType
    ) {
        let itemId = item.id
        let prevTask = tasks[itemId]
        activeCount += 1
        startSession(
            itemId: itemId,
            defectType: item.defectType,
            localImages: localImages,
            existingRemoteCount: existingRemoteURLs.count
        )

        tasks[itemId] = Task { [weak self] in
            _ = await prevTask?.value

            if !localImages.isEmpty {
                do {
                    _ = try await LocalImageStore.shared.save(localImages, for: itemId)
                } catch {
                    self?.logger.warning("[enqueue] LocalImageStore save failed for \(itemId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            PendingErrorUploadStore.shared.addPending(PendingErrorUpload(
                inspectionId:      inspectionId,
                itemId:            itemId,
                severityRaw:       item.severity.rawValue,
                generalCondition:  item.generalCondition,
                defectTypeRaw:     item.defectType?.rawValue,
                comments:          item.comments,
                imageNotes:        item.imageNotes,
                existingRemoteURLs: existingRemoteURLs,
                createdAtISO:      ISO8601DateFormatter().string(from: item.createdAt)
            ))

            let succeeded = await Self.attemptUpload(itemId: itemId, errorRepository: errorRepository)
            self?.tasks[itemId] = nil
            self?.finishSession(itemId: itemId, succeeded: succeeded)
            self?.decrementActiveCount()
        }
    }

    /// Entry point for `PendingUploadRetryService` (app-launch retry) — shares
    /// `attemptUpload` with `enqueue` and the same `activeCount`/`sessions` bookkeeping.
    func retryPending(itemId: String, errorRepository: ErrorRepositoryType) {
        activeCount += 1
        Task { [weak self] in
            if let pending = PendingErrorUploadStore.shared.getAllPending().first(where: { $0.itemId == itemId }) {
                let localImages = await LocalImageStore.shared.load(for: itemId)
                self?.startSession(
                    itemId: itemId,
                    defectType: pending.defectTypeRaw.flatMap { DefectType(rawValue: $0) },
                    localImages: localImages,
                    existingRemoteCount: pending.existingRemoteURLs.count
                )
            }
            let succeeded = await Self.attemptUpload(itemId: itemId, errorRepository: errorRepository)
            self?.finishSession(itemId: itemId, succeeded: succeeded)
            self?.decrementActiveCount()
        }
    }

    private func decrementActiveCount() {
        activeCount = max(0, activeCount - 1)
    }

    // MARK: - Session tracking

    private func startSession(itemId: String, defectType: DefectType?, localImages: [UIImage], existingRemoteCount: Int) {
        let label = defectType?.displayName ?? "Lỗi mới"
        var items: [ImageUploadItem] = (0..<existingRemoteCount).map {
            ImageUploadItem(id: "\(itemId)-\($0)", imageIndex: $0, thumbnail: nil, status: .done)
        }
        items += localImages.enumerated().map { offset, image in
            ImageUploadItem(id: "\(itemId)-\(existingRemoteCount + offset)", imageIndex: existingRemoteCount + offset, thumbnail: image, status: .pending)
        }
        sessions.removeAll { $0.id == itemId }
        sessions.append(FieldUploadSession(id: itemId, fieldLabel: label, items: items))
    }

    private func updateItem(itemId: String, imageIndex: Int, status: ImageUploadStatus) {
        guard let si = sessions.firstIndex(where: { $0.id == itemId }),
              let ii = sessions[si].items.firstIndex(where: { $0.imageIndex == imageIndex }) else { return }
        sessions[si].items[ii].status = status
    }

    /// On success: mark everything `.done` and remove the session shortly after, so the user
    /// briefly sees the completed state (mirrors field sessions clearing on `activeUploadCount
    /// == 0`). On failure: mark unfinished items `.failed` and leave the session visible — no
    /// auto-retry from here, matches the "no retry on failure" rule field uploads already use.
    private func finishSession(itemId: String, succeeded: Bool) {
        guard let idx = sessions.firstIndex(where: { $0.id == itemId }) else { return }
        if succeeded {
            for i in sessions[idx].items.indices { sessions[idx].items[i].status = .done }
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                self?.sessions.removeAll { $0.id == itemId }
            }
        } else {
            for i in sessions[idx].items.indices where sessions[idx].items[i].status != .done {
                sessions[idx].items[i].status = .failed
            }
        }
    }

    /// Loads whatever is pending for `itemId` right now from disk + `PendingErrorUploadStore`
    /// and attempts the real save, wiring `saveErrorItem`'s per-image progress callbacks into
    /// `sessions` so `UploadStatusBottomSheet` reflects live progress. Used by both `enqueue`
    /// (fresh save) and `PendingUploadRetryService` (app-launch retry) — the source of truth is
    /// always disk + the pending store, never in-memory state, so both call sites share one
    /// code path. Returns whether the save ultimately succeeded.
    static func attemptUpload(itemId: String, errorRepository: ErrorRepositoryType) async -> Bool {
        guard let pending = PendingErrorUploadStore.shared.getAllPending().first(where: { $0.itemId == itemId }) else {
            return true
        }

        let localImages = await LocalImageStore.shared.load(for: itemId)
        let sources: [ImageSource] =
            pending.existingRemoteURLs.map { .remote(url: $0) } +
            localImages.map { .local(image: $0) }

        let item = SavedErrorItem(
            id: pending.itemId,
            imageNotes: pending.imageNotes,
            severity: SeverityLevel(rawValue: pending.severityRaw) ?? .low,
            generalCondition: pending.generalCondition,
            defectType: pending.defectTypeRaw.flatMap { DefectType(rawValue: $0) },
            comments: pending.comments,
            createdAt: ISO8601DateFormatter().date(from: pending.createdAtISO) ?? Date()
        )

        do {
            _ = try await errorRepository.saveErrorItem(
                item, imageSources: sources, for: pending.inspectionId,
                onImageProgress: { idx, progress in
                    Task { @MainActor in shared.updateItem(itemId: itemId, imageIndex: idx, status: .uploading(progress: progress)) }
                },
                onImageDone: { idx in
                    Task { @MainActor in shared.updateItem(itemId: itemId, imageIndex: idx, status: .done) }
                },
                onImageFail: { idx in
                    Task { @MainActor in shared.updateItem(itemId: itemId, imageIndex: idx, status: .failed) }
                }
            )
            PendingErrorUploadStore.shared.clearPending(itemId: itemId)
            await LocalImageStore.shared.clear(for: itemId)
            return true
        } catch {
            // Leave pending — next app-launch retry (or the next enqueue for this item) tries again.
            return false
        }
    }
}
