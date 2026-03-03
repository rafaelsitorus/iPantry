//
//  ContentView.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI

struct ContentView: View {
    @State private var capturedImage: UIImage?
    @State private var navigateToMenuList = false
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        NavigationStack {
            CameraScreen(
                capturedImage: $capturedImage,
                navigateToMenuList: $navigateToMenuList,
                onMenuItemsFetched: { items in
                    menuItems = items
                }
            )
            .navigationDestination(isPresented: $navigateToMenuList) {
                MenuListView(menuItems: menuItems, capturedImage: capturedImage)
            }
            .navigationDestination(for: MenuItem.self) { item in
                RecipeDetailView(menuItem: item)
            }
        }
    }
}

#Preview {
    ContentView()
}
