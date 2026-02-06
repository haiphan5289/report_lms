//
//  StorageRepositoryType.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

protocol StorageRepositoryType {
    func uploadImage(_ imageData: Data, path: String) async throws -> String
    func downloadImage(from url: String) async throws -> Data
    func deleteImage(at path: String) async throws
}