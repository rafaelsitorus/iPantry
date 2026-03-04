//
//  ApiKeyRotator.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import Foundation

/// Thread-safe API key rotator using Swift actor.
/// Keys are read from Secrets.plist as a comma-separated string.
/// When a key hits quota/rate-limit it is cooled down for `cooldownSeconds`
/// and the rotator automatically falls back to the next available key.
actor ApiKeyRotator {
    static let shared = ApiKeyRotator()

    /// How long (seconds) a key stays cooled down before being retried
    private let cooldownSeconds: TimeInterval = 60

    private struct KeyEntry {
        let value: String
        var exhaustedAt: Date?

        var isAvailable: Bool {
            guard let exhaustedAt else { return true }
            return Date().timeIntervalSince(exhaustedAt) >= 60
        }
    }

    private var keys: [KeyEntry] = []
    private var currentIndex: Int = 0

    private init() {
        loadKeys()
    }

    // MARK: - Load

    private func loadKeys() {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let raw = dict["GEMINI_API_KEYS"] as? String
        else {
            print("❌ ApiKeyRotator: GEMINI_API_KEYS not found in Secrets.plist")
            return
        }

        var parsed = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "YOUR_GEMINI_API_KEY_HERE" }

        // Deduplicate — identical key values pointing to the same quota are useless duplicates
        var seen = Set<String>()
        parsed = parsed.filter { seen.insert($0).inserted }

        guard !parsed.isEmpty else {
            print("❌ ApiKeyRotator: No valid keys found in GEMINI_API_KEYS")
            return
        }

        // Shuffle at startup so multiple app instances don't all start from key 0
        keys = parsed.shuffled().map { KeyEntry(value: $0) }
        print("✅ ApiKeyRotator: Loaded \(keys.count) unique key(s)")
    }

    // MARK: - Public API

    /// Returns the next available (non-exhausted) key.
    /// - Throws: `GeminiError.allKeysExhausted` if every key is cooled down.
    func nextKey() throws -> String {
        guard !keys.isEmpty else {
            throw GeminiError.allKeysExhausted
        }

        // Try each key starting from currentIndex
        for offset in 0 ..< keys.count {
            let idx = (currentIndex + offset) % keys.count
            if keys[idx].isAvailable {
                currentIndex = idx
                return keys[idx].value
            }
        }

        // All keys are cooling down — find the one that recovers soonest
        let soonest = keys
            .compactMap { $0.exhaustedAt.map { (key: $0, t: $0) } }
            .min(by: { $0.t < $1.t })

        let wait = soonest.map {
            max(0, cooldownSeconds - Date().timeIntervalSince($0.t))
        } ?? cooldownSeconds

        throw GeminiError.allKeysExhausted
    }

    /// Call this when a key receives a 429 / quota-exceeded response (temporary cooldown).
    func markExhausted(key: String) {
        // Mark ALL entries with this value — handles the edge case of accidental duplicates
        for idx in keys.indices where keys[idx].value == key {
            keys[idx].exhaustedAt = Date()
        }
        print("⚠️  ApiKeyRotator: Key …\(key.suffix(6)) exhausted. Will retry after \(Int(cooldownSeconds))s")
        advanceIndex()
    }

    /// Call this when a key is permanently invalid (403 leaked / revoked).
    /// Removes it from the pool entirely so it is never tried again.
    func markPermanentlyFailed(key: String) {
        let before = keys.count
        keys.removeAll { $0.value == key }
        let removed = before - keys.count
        if removed > 0 {
            print("🚫 ApiKeyRotator: Key …\(key.suffix(6)) permanently removed (\(removed) entr\(removed == 1 ? "y" : "ies"))")
        }
        // Reset index safely for the new (smaller) array
        if keys.isEmpty {
            currentIndex = 0
        } else {
            currentIndex = currentIndex % keys.count
        }
    }

    private func advanceIndex() {
        guard !keys.isEmpty else { return }
        currentIndex = (currentIndex + 1) % keys.count
    }

    /// Call this when a key succeeds — clears its exhausted state if it had recovered.
    func markSuccess(key: String) {
        if let idx = keys.firstIndex(where: { $0.value == key }) {
            keys[idx].exhaustedAt = nil
        }
    }

    /// Counts currently available (non-cooled-down) keys.
    var availableCount: Int {
        keys.filter { $0.isAvailable }.count
    }

    var totalCount: Int { keys.count }
}
