//
//  MenuItem.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import Foundation

struct MenuItem: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let description: String
    let imagePrompt: String
    let ingredients: [String]
    let instructions: [String]
    let cookingTime: String
    let servings: String
    
    enum CodingKeys: String, CodingKey {
        case name, description, imagePrompt, ingredients, instructions, cookingTime, servings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.imagePrompt = try container.decodeIfPresent(String.self, forKey: .imagePrompt) ?? ""
        self.ingredients = try container.decode([String].self, forKey: .ingredients)
        self.instructions = try container.decode([String].self, forKey: .instructions)
        self.cookingTime = try container.decodeIfPresent(String.self, forKey: .cookingTime) ?? "30 mins"
        self.servings = try container.decodeIfPresent(String.self, forKey: .servings) ?? "2 servings"
    }
    
    init(name: String, description: String, imagePrompt: String = "", ingredients: [String], instructions: [String], cookingTime: String = "30 mins", servings: String = "2 servings") {
        self.id = UUID()
        self.name = name
        self.description = description
        self.imagePrompt = imagePrompt
        self.ingredients = ingredients
        self.instructions = instructions
        self.cookingTime = cookingTime
        self.servings = servings
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]?
    
    struct Candidate: Codable {
        let content: Content?
    }
    
    struct Content: Codable {
        let parts: [Part]?
    }
    
    struct Part: Codable {
        let text: String?
        let thought: Bool?
    }
    
    /// Extracts the actual text output, skipping any "thinking" parts
    var outputText: String? {
        guard let parts = candidates?.first?.content?.parts else { return nil }
        // Find the last non-thought part that has text
        for part in parts.reversed() {
            if part.thought != true, let text = part.text, !text.isEmpty {
                return text
            }
        }
        // Fallback: return any part with text
        return parts.first(where: { $0.text != nil })?.text
    }
}
