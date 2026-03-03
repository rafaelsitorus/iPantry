//
//  MenuListView.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI

struct MenuListView: View {
    let menuItems: [MenuItem]
    let capturedImage: UIImage?
    
    @Environment(\.dismiss) var dismiss
    
    // Color palette for cards
    private let cardColors: [Color] = [
        Color(red: 1.0, green: 0.6, blue: 0.4),   // Salmon/Orange
        Color(red: 0.4, green: 0.8, blue: 0.7),   // Teal
        Color(red: 0.95, green: 0.75, blue: 0.3),  // Golden Yellow
        Color(red: 0.6, green: 0.5, blue: 0.9),   // Purple
        Color(red: 0.9, green: 0.45, blue: 0.5),  // Rose
    ]
    
    // Food emojis for cards
    private let foodEmojis = ["🍝", "🥘", "🍲", "🥗", "🍛", "🍜", "🥙", "🌮", "🍕", "🥞"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Recipes")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Based on your ingredients")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Menu Cards
                LazyVStack(spacing: 16) {
                    ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item) {
                            MenuCard(
                                item: item,
                                color: cardColors[index % cardColors.count],
                                emoji: foodEmojis[index % foodEmojis.count]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MenuCard: View {
    let item: MenuItem
    let color: Color
    let emoji: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 64, height: 64)
                
                Text(emoji)
                    .font(.system(size: 32))
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(item.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(item.cookingTime, systemImage: "clock")
                    Label(item.servings, systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
}
