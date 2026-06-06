//
//  UIImage+Upload.swift
//  report_lms
//

import UIKit

extension UIImage {
    /// Resize to maxDimension (preserving aspect ratio) then compress to JPEG.
    /// Called on a background thread — never on MainActor.
    func prepareForUpload(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.8) -> Data? {
        let resized = resizedIfNeeded(maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    private func resizedIfNeeded(maxDimension: CGFloat) -> UIImage {
        guard size.width > maxDimension || size.height > maxDimension else { return self }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
