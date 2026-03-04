//
//  GeminiService.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import Foundation
import UIKit

class GeminiService {
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    // MARK: - Public entry point (auto key rotation)

    static func getMenuRecommendations(from image: UIImage) async throws -> [MenuItem] {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw GeminiError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

        let rotator = ApiKeyRotator.shared
        let maxAttempts = max(await rotator.totalCount, 1)
        var lastError: Error = GeminiError.allKeysExhausted

        for attempt in 1...maxAttempts {
            let key: String
            do {
                key = try await rotator.nextKey()
            } catch {
                throw GeminiError.allKeysExhausted
            }

            do {
                let items = try await performRequest(base64Image: base64Image, apiKey: key)
                await rotator.markSuccess(key: key)
                return items
            } catch GeminiError.keyExhausted(let exhaustedKey) {
                // Temporary quota / rate-limit — cooldown and retry
                await rotator.markExhausted(key: exhaustedKey)
                print("🔄 Key rotation: attempt \(attempt)/\(maxAttempts), trying next key…")
                lastError = GeminiError.keyExhausted(key: exhaustedKey)
                continue
            } catch GeminiError.keyPermanentlyFailed(let badKey) {
                // Leaked / revoked key — remove from pool permanently and retry
                await rotator.markPermanentlyFailed(key: badKey)
                print("🔄 Key rotation (permanent failure): attempt \(attempt)/\(maxAttempts), trying next key…")
                lastError = GeminiError.keyPermanentlyFailed(key: badKey)
                continue
            } catch {
                throw error
            }
        }

        throw lastError
    }

    // MARK: - Single request

    private static func performRequest(base64Image: String, apiKey: String) async throws -> [MenuItem] {
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            First, check whether the image contains edible food or drink ingredients (raw, cooked, packaged food, fruits, vegetables, meat, spices, etc.).

                            If the image does NOT contain any edible food ingredients, respond with exactly one word (no punctuation, no explanation):
                            NOT_FOOD

                            If the image DOES contain food ingredients, suggest 3 short recipes using them.
                            Return ONLY a JSON array (no markdown). Keep descriptions under 15 words. Keep each instruction step under 15 words. Max 5 ingredients and 5 steps per recipe.
                            [{"name":"Name","description":"Short desc","imagePrompt":"dish image desc","ingredients":["item 1","item 2"],"instructions":["Step 1","Step 2"],"cookingTime":"30 mins","servings":"4 servings"}]
                            """
                        ],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 4096
            ]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        print("📡 Gemini request → key …\(apiKey.suffix(6)) | body \(request.httpBody?.count ?? 0) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)
        let rawBody = String(data: data, encoding: .utf8) ?? "(binary / not utf8)"

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        print("""
        ──────────────────────────────────────
        📥 Gemini response  HTTP \(httpResponse.statusCode)  key …\(apiKey.suffix(6))
        \(rawBody)
        ──────────────────────────────────────
        """)

        // Rate-limit / quota exhausted → signal rotation
        if httpResponse.statusCode == 429 {
            throw GeminiError.keyExhausted(key: apiKey)
        }
        if httpResponse.statusCode == 403 {
            throw GeminiError.keyPermanentlyFailed(key: apiKey)
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: rawBody)
        }

        // Decode envelope
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            print("❌ Failed to decode GeminiResponse: \(error)")
            throw GeminiError.parsingError
        }

        guard let text = geminiResponse.outputText else {
            print("No output text found in Gemini response")
            throw GeminiError.noContent
        }

        print("Gemini raw text: \(text.prefix(500))")

        // Non-food detection — Gemini returns "NOT_FOOD" when no edible items are found
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.uppercased().hasPrefix("NOT_FOOD") {
            throw GeminiError.notFood
        }

        var cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIdx = cleanedText.firstIndex(of: "["),
           let endIdx = cleanedText.lastIndex(of: "]") {
            cleanedText = String(cleanedText[startIdx...endIdx])
        }

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw GeminiError.parsingError
        }

        do {
            return try JSONDecoder().decode([MenuItem].self, from: jsonData)
        } catch {
            print("Failed to decode menu items: \(error)")
            print("Cleaned JSON: \(cleanedText.prefix(500))")
            throw GeminiError.parsingError
        }
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case parsingError
    case notFood
    case keyExhausted(key: String)
    case keyPermanentlyFailed(key: String)
    case allKeysExhausted

    var errorDescription: String? {
        switch self {
        case .invalidImage:     return "Failed to process the captured image."
        case .invalidURL:       return "Invalid API URL."
        case .invalidResponse:  return "Invalid response from server."
        case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
        case .noContent:        return "No content in API response."
        case .parsingError:     return "Failed to parse recipe data."
        case .notFood:          return "No edible food ingredients detected."
        case .keyExhausted:           return "API key quota exceeded, rotating to next key."
        case .keyPermanentlyFailed:    return "API key is invalid or revoked, removing from pool."
        case .allKeysExhausted:        return "All API keys are exhausted. Please try again in a minute."
        }
    }
}
