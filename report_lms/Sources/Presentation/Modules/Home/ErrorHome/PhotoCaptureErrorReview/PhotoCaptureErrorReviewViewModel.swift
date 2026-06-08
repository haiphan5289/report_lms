//
//  PhotoCaptureReviewViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import OSLog

// MARK: - Photo Capture Review ViewModel
@MainActor
final class PhotoCaptureErrorReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var images: [ImageWithNote] = []
    @Published var showCamera = false
    @Published var selectedSeverity: SeverityLevel = .low
    @Published var generalConditionEnabled = false
    @Published var selectedGeneralCondition: Int?
    @Published var selectedDefectType: DefectType?
    @Published var comments: String = ""
    @Published var isDownloading = false
    @Published var errorMessage: String?
    @Published var snackbarMessage: String?

    // MARK: - Private Properties
    let inspectionId: String  // Internal for debug access
    private let errorRepository: ErrorRepositoryType
    private let logger = Logger(subsystem: "com.reportlms", category: "PhotoCaptureErrorReviewViewModel")
    private var editingItemId: String?

    // MARK: - Computed Properties
    var isEditMode: Bool { editingItemId != nil }

    var localImages: [UIImage] {
        images.compactMap { if case .local(let img) = $0.source { return img } else { return nil } }
    }

    // MARK: - Initialization
    init(inspectionId: String, editingItem: SavedErrorItem? = nil, errorRepository: ErrorRepositoryType? = nil) {
        self.inspectionId = inspectionId
        guard let repo = errorRepository ?? Container.shared.resolve(ErrorRepositoryType.self) else {
            fatalError("ErrorRepositoryType not registered in DI container")
        }
        self.errorRepository = repo
        if let item = editingItem {
            editingItemId = item.id
            selectedSeverity = item.severity
            generalConditionEnabled = item.generalCondition != nil
            selectedGeneralCondition = item.generalCondition
            selectedDefectType = item.defectType
            comments = item.comments
        }
    }

    // MARK: - Image Management
    func addImages(_ newImages: [UIImage]) {
        Task {
            let resized = await Task.detached(priority: .userInitiated) {
                newImages.map { $0.resized(maxDimension: 1600) }
            }.value
            images.append(contentsOf: resized.map { ImageWithNote(source: .local(image: $0)) })
        }
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
    }

    func setInitialImages(_ initialImages: [ImageWithNote]) async {
        images = initialImages

        guard isEditMode, let itemId = editingItemId else { return }

        // Check LocalImageStore first — avoids Storage download for pending-upload items
        let cachedImages = await LocalImageStore.shared.load(for: itemId)
        if !cachedImages.isEmpty {
            print("🔍 [PhotoCaptureErrorReviewVM] Loaded \(cachedImages.count) images from LocalImageStore (cache hit)")
            images = cachedImages.map { ImageWithNote(source: .local(image: $0)) }
            return
        }

        // AC-14: Fall back to downloading remote images
        let remoteImages = images.filter {
            if case .remote = $0.source { return true }
            return false
        }
        guard !remoteImages.isEmpty else {
            print("🔍 [PhotoCaptureErrorReviewVM] No remote images to download - all images are local ✅")
            return
        }

        print("🔍 [PhotoCaptureErrorReviewVM] Auto-downloading \(remoteImages.count) remote images in edit mode")
        isDownloading = true
        for (index, imageWithNote) in images.enumerated() {
            if case .remote(let url) = imageWithNote.source {
                do {
                    let downloadedImage = try await downloadImage(from: url)
                    images[index] = ImageWithNote(source: .local(image: downloadedImage), note: imageWithNote.note)
                    print("   - Downloaded image \(index + 1)/\(remoteImages.count)")
                } catch {
                    print("   - Failed to download image \(index): \(error)")
                }
            }
        }
        isDownloading = false
        print("   - Auto-download complete ✅")
    }

    func replaceImage(at index: Int, with image: UIImage) {
        guard index >= 0 && index < images.count else { return }
        print("🔍 [PhotoCaptureErrorReviewVM] replaceImage at index \(index)")
        print("   - Old source: \(images[index].source)")
        print("   - New image size: \(image.size)")
        // Create new ImageWithNote to force SwiftUI to recreate the view
        let currentNote = images[index].note
        images[index] = ImageWithNote(source: .local(image: image), note: currentNote)
        print("   - New source: \(images[index].source)")
        print("   - Replaced successfully ✅")
    }

    func downloadImage(from url: String) async throws -> UIImage {
        print("🔍 [PhotoCaptureErrorReviewVM] downloadImage()")
        print("   - URL: \(url)")
        guard let imageURL = URL(string: url) else {
            print("   - ❌ Bad URL")
            throw URLError(.badURL)
        }
        
        // ✅ Use ImageCacheActor for cached download
        let image: UIImage
        if let cached = await ImageCacheActor.shared.image(for: imageURL) {
            print("   - ✅ Cache hit")
            image = cached
        } else {
            print("   - 📥 Downloading from network")
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            print("   - Downloaded \(data.count) bytes")
            guard let downloaded = UIImage(data: data) else {
                print("   - ❌ Cannot decode image")
                throw URLError(.cannotDecodeContentData)
            }
            // Store in cache for future use
            await ImageCacheActor.shared.store(downloaded, for: imageURL)
            image = downloaded
        }
        
        print("   - Original image size: \(image.size)")
        print("   - Original image scale: \(image.scale)")
        
        // Resize if too large (prevents memory issues in compositing)
        let maxDimension: CGFloat = 2048
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let resized = resizeImage(image, maxDimension: maxDimension)
            print("   - ⚠️ Image too large, resized to: \(resized.size)")
            return resized
        }
        
        return image
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Defect Type
    func defectTypeSearchableData() -> [ListItemProtocol] {
        let categories: [String] = ["PA", "SU", "AS", "FU", "SA", "FI", "CO", "FE", "TA"]
        return categories.compactMap { category -> ListItemProtocol? in
            let items = DefectType.allCases.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            let datas = items.map { ListDataItem(id: $0.rawValue.hashValue, name: $0.displayName) }
            return ErrorReviewListItem(title: items[0].categoryDisplayName, datas: datas)
        }
    }

    func selectDefectType(from item: ListDataItem) {
        let code = item.name.components(separatedBy: " - ").first ?? ""
        selectedDefectType = DefectType(rawValue: code)
    }

    // MARK: - Persistence

    /// Builds SavedErrorItem and returns immediately (dismiss-first).
    /// Disk save + Firestore write run in a background Task — does not block UI.
    func saveReview() -> SavedErrorItem? {
        guard !images.isEmpty else {
            errorMessage = "Vui lòng chụp ít nhất một ảnh"
            return nil
        }

        let item = buildSavedErrorItem()
        let localImages: [UIImage] = images.compactMap {
            if case .local(let img) = $0.source { return img } else { return nil }
        }
        logger.debug("[saveReview] START inspectionId=\(self.inspectionId, privacy: .public) imageCount=\(self.images.count, privacy: .public)")

        Task {
            if !localImages.isEmpty {
                do {
                    _ = try await LocalImageStore.shared.save(localImages, for: item.id)
                    logger.debug("[saveReview] ✅ Saved \(localImages.count, privacy: .public) images to LocalImageStore")
                } catch {
                    logger.warning("[saveReview] ⚠️ LocalImageStore save failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            do {
                _ = try await errorRepository.saveErrorItem(item, imageSources: [], for: inspectionId)
                logger.debug("[saveReview] ✅ Firestore metadata saved")
            } catch {
                logger.error("[saveReview] ❌ Firestore write failed: \(error, privacy: .public)")
            }
        }

        return item
    }

    /// Returns immediately (dismiss-first). Disk save + Firestore write run in a background Task.
    /// No Firebase Storage upload — mirrors saveReview() behavior.
    func updateReview() -> SavedErrorItem? {
        let item = buildSavedErrorItem()
        let localImages: [UIImage] = images.compactMap {
            if case .local(let img) = $0.source { return img } else { return nil }
        }
        logger.debug("[updateReview] START inspectionId=\(self.inspectionId, privacy: .public) imageCount=\(self.images.count, privacy: .public)")

        Task {
            if !localImages.isEmpty {
                do {
                    _ = try await LocalImageStore.shared.save(localImages, for: item.id)
                    logger.debug("[updateReview] ✅ Saved \(localImages.count, privacy: .public) images to LocalImageStore")
                } catch {
                    logger.warning("[updateReview] ⚠️ LocalImageStore save failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            do {
                _ = try await errorRepository.saveErrorItem(item, imageSources: [], for: inspectionId)
                logger.debug("[updateReview] ✅ Firestore metadata saved")
            } catch {
                logger.error("[updateReview] ❌ Firestore write failed: \(error, privacy: .public)")
            }
        }

        return item
    }

    // MARK: - Private Methods
    private func buildSavedErrorItem() -> SavedErrorItem {
        let existingURLs = images.compactMap { item -> String? in
            if case .remote(let url) = item.source { return url } else { return nil }
        }
        return SavedErrorItem(
            id: editingItemId ?? UUID().uuidString,
            imageURLs: existingURLs,
            imageNotes: images.map { $0.note },
            severity: selectedSeverity,
            generalCondition: generalConditionEnabled ? selectedGeneralCondition : nil,
            defectType: selectedDefectType,
            comments: comments
        )
    }
}

// MARK: - List Item for Searchable Data
struct ErrorReviewListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}
