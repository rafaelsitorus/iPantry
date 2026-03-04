//
//  RecipeDetailView.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI

struct RecipeDetailView: View {
    let menuItem: MenuItem
    
    @Environment(\.dismiss) var dismiss
    
    // Gradient for the header image placeholder
    private let headerGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.6, blue: 0.3),
            Color(red: 0.9, green: 0.3, blue: 0.2)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image Header
                ZStack(alignment: .bottomLeading) {
                    headerGradient
                        .frame(height: 280)
                        .overlay(
                            VStack {
                                Text("🍽️")
                                    .font(.system(size: 80))
                                Text(menuItem.name)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.top, 4)
                            }
                        )
                    
                    // Gradient overlay at bottom for readability
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                }
                .frame(height: 280)
                
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title & Meta
                    VStack(alignment: .leading, spacing: 12) {
                        Text(menuItem.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(menuItem.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                        
                        HStack(spacing: 20) {
                            InfoBadge(icon: "clock.fill", text: menuItem.cookingTime, color: .orange)
                            InfoBadge(icon: "person.2.fill", text: menuItem.servings, color: .blue)
                            InfoBadge(icon: "list.bullet", text: "\(menuItem.ingredients.count) items", color: .green)
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Ingredients Section
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Ingredients", icon: "basket.fill")
                        
                        VStack(spacing: 0) {
                            ForEach(Array(menuItem.ingredients.enumerated()), id: \.offset) { index, ingredient in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(ingredient)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(
                                    index % 2 == 0
                                    ? Color(.systemGray6)
                                    : Color.clear
                                )
                            }
                        }
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    
                    // Instructions Section
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Instructions", icon: "list.number")
                        
                        VStack(spacing: 16) {
                            ForEach(Array(menuItem.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 14) {
                                    // Step Number
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.orange, .red],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(instruction)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Supporting Views

struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.orange)
            
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}
