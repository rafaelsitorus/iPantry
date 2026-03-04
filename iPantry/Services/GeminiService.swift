//
//  GeminiService.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import Foundation
import UIKit

class GeminiService {
    static let apiKey = "AIzaSyC9PuKQ6BLpM4jl0lpeTJdGyd7dBXTZKlk"
    
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    static func getMenuRecommendations(from image: UIImage) async throws -> [MenuItem] {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw GeminiError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            Look at this image of ingredients. Suggest 3 short recipes using them.
                            
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
                "maxOutputTokens": 16384
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8) ?? "(not utf8)"
            print("Failed to decode GeminiResponse: \(error)")
            print("Raw API body: \(rawBody.prefix(1000))")
            throw GeminiError.parsingError
        }
        
        guard let text = geminiResponse.outputText else {
            print("No output text found in Gemini response")
            throw GeminiError.noContent
        }
        
        print("Gemini raw text: \(text.prefix(500))")
        
        // Clean the response text - remove markdown code blocks if present
        var cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON array if there's extra text around it
        if let startIdx = cleanedText.firstIndex(of: "["),
           let endIdx = cleanedText.lastIndex(of: "]") {
            cleanedText = String(cleanedText[startIdx...endIdx])
        }
        
        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw GeminiError.parsingError
        }
        
        let menuItems: [MenuItem]
        do {
            menuItems = try JSONDecoder().decode([MenuItem].self, from: jsonData)
        } catch {
            print("Failed to decode menu items: \(error)")
            print("Cleaned JSON: \(cleanedText.prefix(500))")
            throw GeminiError.parsingError
        }
        return menuItems
    }
    
    static func generateDishImage(prompt: String) async throws -> UIImage {
        // Use Gemini to generate a text description, then use a placeholder
        // For real image generation, you'd use DALL-E, Stable Diffusion, or Imagen
        // Here we'll create a styled placeholder
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Gradient background
            let colors = [
                UIColor.systemOrange.withAlphaComponent(0.3).cgColor,
                UIColor.systemBrown.withAlphaComponent(0.5).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors as CFArray,
                                       locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient,
                                                  start: .zero,
                                                  end: CGPoint(x: size.width, y: size.height),
                                                  options: [])
            
            // Food emoji icon
            let emoji = "🍽️"
            let emojiFont = UIFont.systemFont(ofSize: 60)
            let emojiAttrs: [NSAttributedString.Key: Any] = [.font: emojiFont]
            let emojiSize = emoji.size(withAttributes: emojiAttrs)
            emoji.draw(at: CGPoint(x: (size.width - emojiSize.width) / 2,
                                    y: (size.height - emojiSize.height) / 2 - 20),
                        withAttributes: emojiAttrs)
            
            // Dish name
            let nameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: UIColor.white
            ]
            let truncatedPrompt = String(prompt.prefix(40))
            let nameSize = truncatedPrompt.size(withAttributes: nameAttrs)
            truncatedPrompt.draw(at: CGPoint(x: (size.width - nameSize.width) / 2,
                                              y: (size.height - nameSize.height) / 2 + 50),
                                  withAttributes: nameAttrs)
        }
        
        return image
    }
}

enum GeminiError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Failed to process the captured image."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .noContent:
            return "No content in API response."
        case .parsingError:
            return "Failed to parse recipe data."
        }
    }
}
