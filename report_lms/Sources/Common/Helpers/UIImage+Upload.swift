//
//  UIImage+Upload.swift
//  report_lms
//

import UIKit
import ImageIO
import Foundation

extension Data {
    /// Sniffs the first bytes to return the MIME type for Firebase Storage metadata.
    /// Avoids Firebase having to detect content type on the server side.
    var imageContentType: String {
        guard count >= 4 else { return "image/jpeg" }
        // WebP: starts with RIFF (52 49 46 46)
        if self[0] == 0x52, self[1] == 0x49, self[2] == 0x46, self[3] == 0x46 { return "image/webp" }
        // JPEG: starts with FF D8 FF
        if self[0] == 0xFF, self[1] == 0xD8, self[2] == 0xFF { return "image/jpeg" }
        return "image/jpeg"
    }
}

extension UIImage {
    /// Resize to maxDimension (preserving aspect ratio) then encode.
    /// Tries WebP first (iOS 14+, ~35% smaller than JPEG at same quality); falls back to JPEG.
    /// Called on a background thread — never on MainActor.
    func prepareForUpload(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.8) -> Data? {
        let resized = resizedIfNeeded(maxDimension: maxDimension)
        return resized.webPData(quality: compressionQuality)
            ?? resized.jpegData(compressionQuality: compressionQuality)
    }

    func resized(maxDimension: CGFloat = 1600) -> UIImage {
        resizedIfNeeded(maxDimension: maxDimension)
    }

    // WebP encode via ImageIO (iOS 14+). Returns nil on failure → caller falls back to JPEG.
    // Normalizes orientation before encoding — cgImage is raw sensor data and ignores
    // imageOrientation, which would produce a rotated image on portrait camera captures.
    private func webPData(quality: CGFloat) -> Data? {
        guard #available(iOS 14, *) else { return nil }
        let source = imageOrientation == .up ? self : orientationNormalized()
        guard let cgImage = source.cgImage else { return nil }
        let buffer = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            buffer, "org.webmproject.webp" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? buffer as Data : nil
    }

    // Re-draw through UIGraphicsImageRenderer to bake orientation into pixel data.
    // Used only when imageOrientation != .up and image is already within maxDimension.
    private func orientationNormalized() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedIfNeeded(maxDimension: CGFloat) -> UIImage {
        guard size.width > maxDimension || size.height > maxDimension else { return self }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        // scale=1.0: output pixel dimensions == point dimensions regardless of display scale.
        // Without this, UIGraphicsImageRenderer defaults to UIScreen.main.scale (3x on Pro models),
        // producing a 4800×3600 bitmap when 1600×1200 was intended — 9× larger than needed.
        // Also: UIScreen.main must not be accessed off the main thread; explicit scale avoids that.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
