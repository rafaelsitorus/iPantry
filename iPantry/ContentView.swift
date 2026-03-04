//
//  ContentView.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI

enum AppRoute: Hashable {
    case menuList([MenuItem])
    case recipeDetail(MenuItem)
}

struct ContentView: View {
    @State private var capturedImage: UIImage?
    @State private var path = NavigationPath()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                CameraScreen(
                    capturedImage: $capturedImage,
                    onComplete: { items in
                        path.append(AppRoute.menuList(items))
                    }
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .menuList(let items):
                        MenuListView(menuItems: items, capturedImage: capturedImage, path: $path)
                    case .recipeDetail(let item):
                        RecipeDetailView(menuItem: item)
                    }
                }
            }
            .onChange(of: path) { _, newPath in
                // When fully navigated back to root, clear the captured image
                if newPath.isEmpty {
                    capturedImage = nil
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
