//
//  RecipeViewModel.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//
import Foundation
import GoogleGenerativeAI
import UIKit

@MainActor
class RecipeViewModel: ObservableObject {
    // COPY API KEY KAMU DARI GOOGLE AI STUDIO KE SINI
    private let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: "AIzaSyBTouUMnjBgT976_QSyEhPbskeWdwWkh4Q")
    
    @Published var recipeText: String = "Halo! Silakan foto bahan makananmu."
    @Published var isProcessing: Bool = false

    func generateRecipe(from image: UIImage) async {
        isProcessing = true
        recipeText = "Sedang meracik resep..."
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let part = ModelContent.Part.data(mimetype: "image/jpeg", imageData)

        do {
            let response = try await model.generateContent("Identifikasi bahan makanan ini dan buat resep lengkap dalam Bahasa Indonesia.", part)
            self.recipeText = response.text ?? "Gagal mendapatkan resep."
        } catch {
            self.recipeText = "Error: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}
