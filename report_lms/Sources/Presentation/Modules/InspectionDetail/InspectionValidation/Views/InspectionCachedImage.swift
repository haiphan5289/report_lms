//
//  InspectionCachedImage.swift
//  report_lms
//
//  Three-tier image loader for inspection remote photos:
//    1. InspectionImageCacheActor (Documents/ — durable, survives iOS storage pressure)
//    2. ImageCacheActor           (Caches/    — fast, may be purged by iOS)
//    3. Network fetch             (Firebase Storage)
//
//  After a network fetch, the image is written to BOTH caches so subsequent opens
//  are instant even if iOS has purged the Caches directory.
//

import SwiftUI

struct InspectionCachedImage<Content: View>: View {
    let url: URL
    let inspectionId: String
    let fieldId: String
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url.absoluteString) { await load() }
    }

    // MARK: - Load

    private func load() async {
        guard !Task.isCancelled else { return }

        // 1. Durable docs-dir cache (survives memory pressure + iOS Caches purge)
        if let img = await InspectionImageCacheActor.shared.loadRemote(
            url: url, inspectionId: inspectionId, fieldId: fieldId
        ) {
            phase = .success(Image(uiImage: img))
            return
        }

        guard !Task.isCancelled else { return }

        // 2. RAM / Caches-dir cache (fast but ephemeral)
        if let img = await ImageCacheActor.shared.image(for: url) {
            phase = .success(Image(uiImage: img))
            // Promote to durable cache for the next session
            Task.detached(priority: .background) {
                await InspectionImageCacheActor.shared.cacheRemote(
                    image: img, url: url, inspectionId: inspectionId, fieldId: fieldId
                )
            }
            return
        }

        guard !Task.isCancelled else { return }

        // 3. Network fetch
        phase = .empty
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }

            let decoded = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.preparingForDisplay()
            }.value

            guard let img = decoded else {
                phase = .failure(URLError(.badServerResponse))
                return
            }

            // Write to both caches in background
            Task.detached(priority: .background) {
                await ImageCacheActor.shared.store(img, for: url)
                await InspectionImageCacheActor.shared.cacheRemote(
                    image: img, url: url, inspectionId: inspectionId, fieldId: fieldId
                )
            }

            phase = .success(Image(uiImage: img))
        } catch {
            phase = .failure(error)
        }
    }
}
