//
//  CachedAsyncImage.swift
//  report_lms
//

import SwiftUI

/// AsyncImage replacement with RAM + disk caching via ImageCacheActor.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url?.absoluteString) { await load() }
    }

    // MARK: - Private

    private func load() async {
        guard let url else { phase = .empty; return }

        // 1. RAM / disk cache hit
        if let cached = await ImageCacheActor.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        guard !Task.isCancelled else { return }

        // 2. Network fetch
        phase = .empty
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard !Task.isCancelled else { return }

            // Decode + pre-render off the main thread to avoid frame drops on first display.
            let decoded = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.preparingForDisplay()
            }.value
            guard let img = decoded else {
                phase = .failure(URLError(.badServerResponse))
                return
            }

            await ImageCacheActor.shared.store(img, for: url)
            phase = .success(Image(uiImage: img))
        } catch {
            phase = .failure(error)
        }
    }
}
