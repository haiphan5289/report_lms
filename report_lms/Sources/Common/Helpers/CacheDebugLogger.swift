//
//  CacheDebugLogger.swift
//  report_lms
//
//  Debug-only realtime event log for the inspection image cache + upload pipeline.
//  Access via CacheDebugLogger.shared from any actor/thread (nonisolated log() method).
//

import Foundation

// Not @MainActor at the class level — log() must be callable from any actor.
// All @Published mutations go through Task { @MainActor in ... } to stay on the main thread.
final class CacheDebugLogger: ObservableObject {
    // nonisolated(unsafe): shared is written once at program start and never mutated again.
    nonisolated(unsafe) static let shared = CacheDebugLogger()

    // MARK: - Event types

    enum CacheEvent {
        case diskWrite(tag: String, sizeKB: Int)
        case diskHit(tag: String)
        case ramHit(tag: String)
        case pendingAdded(fieldId: String, count: Int)
        case retryStarted(imageCount: Int)
        case uploadSuccess(fieldId: String)
        case evicted(inspectionId: String)

        var emoji: String {
            switch self {
            case .diskWrite:     return "⬇"
            case .diskHit:       return "💾"
            case .ramHit:        return "⚡"
            case .pendingAdded:  return "📋"
            case .retryStarted:  return "🔄"
            case .uploadSuccess: return "✅"
            case .evicted:       return "🗑"
            }
        }

        var label: String {
            switch self {
            case .diskWrite(let tag, let kb):   return "DISK WRITE \(tag) (\(kb) KB)"
            case .diskHit(let tag):             return "DISK HIT \(tag)"
            case .ramHit(let tag):              return "RAM HIT \(tag)"
            case .pendingAdded(let f, let n):   return "PENDING +1 \(f) → \(n) total"
            case .retryStarted(let n):          return "RETRY UPLOAD \(n) image(s)"
            case .uploadSuccess(let f):         return "UPLOAD SUCCESS \(f)"
            case .evicted(let id):              return "EVICTED \(id)"
            }
        }
    }

    // MARK: - Log entry

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let event: CacheEvent
    }

    // MARK: - Published state

    @MainActor @Published private(set) var entries: [LogEntry] = []

    init() {}

    // MARK: - Log — callable from any actor or thread

    func log(_ event: CacheEvent) {
        let ts = Self.currentTimestamp()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let entry = LogEntry(timestamp: ts, event: event)
            self.entries.insert(entry, at: 0)
            if self.entries.count > 60 {
                self.entries = Array(self.entries.prefix(60))
            }
        }
    }

    @MainActor func clear() {
        entries = []
    }

    // MARK: - Private

    private static func currentTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
