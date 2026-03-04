//
//  CameraScreen.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI
import PhotosUI

//
//  CameraScreen.swift
//  iPantry
//
//  Created by Academy on 03/03/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct CameraScreen: View {
    @Binding var capturedImage: UIImage?
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var capturedPreview: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showNotFoodAlert = false
    @State private var flashAnimation = false

    var onComplete: ([MenuItem]) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iPantry")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Snap your ingredients")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: Camera / Preview box
                ZStack {
                    if let preview = capturedPreview {
                        // Show captured image preview
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: cameraBoxHeight)
                            .clipped()
                            .cornerRadius(20)
                    } else if cameraManager.isAuthorized {
                        // Live camera feed
                        CameraPreviewView(session: cameraManager.session)
                            .frame(maxWidth: .infinity)
                            .frame(height: cameraBoxHeight)
                            .cornerRadius(20)
                            .clipped()
                    } else {
                        // Placeholder while waiting for permission
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: cameraBoxHeight)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Requesting camera access…")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            )
                    }

                    // Flash animation on capture
                    if flashAnimation {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: cameraBoxHeight)
                            .allowsHitTesting(false)
                    }

                    // Loading overlay
                    if isLoading {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: cameraBoxHeight)
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                            Text("Analyzing ingredients…")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                        }
                    }

                    // Retake button overlay (top-right when preview is shown)
                    if capturedPreview != nil && !isLoading {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    capturedPreview = nil
                                    capturedImage = nil
                                    cameraManager.startSession()
                                } label: {
                                    Label("Retake", systemImage: "arrow.counterclockwise")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(.black.opacity(0.55))
                                        .cornerRadius(20)
                                }
                                .padding(12)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // MARK: Bottom controls
                VStack(spacing: 20) {
                    HStack(alignment: .center, spacing: 40) {
                        // Gallery button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                                Text("Gallery")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .disabled(isLoading)

                        // Capture button
                        Button {
                            triggerCapture()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 78, height: 78)
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 5)
                                    .frame(width: 92, height: 92)
                            }
                        }
                        .disabled(isLoading || (!cameraManager.isAuthorized && capturedPreview == nil))

                        // Spacer to balance the layout
                        Color.clear
                            .frame(width: 52)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.configure()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: capturedImage) { _, newVal in
            // ContentView clears capturedImage when user returns to root
            if newVal == nil {
                capturedPreview = nil
                cameraManager.capturedImage = nil
                cameraManager.startSession()
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, image in
            guard let image else { return }
            // Trigger flash
            withAnimation(.easeIn(duration: 0.05)) { flashAnimation = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.15)) { flashAnimation = false }
            }
            cameraManager.stopSession()
            capturedPreview = image
            capturedImage = image
            analyzeImage(image)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let newItem { loadPhoto(from: newItem) }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .alert("Bukan Makanan 🚫", isPresented: $showNotFoodAlert) {
            Button("Coba Lagi") {
                capturedPreview = nil
                capturedImage = nil
                cameraManager.startSession()
            }
        } message: {
            Text("Gambar tidak mengandung bahan makanan. Silakan foto bahan masakan seperti sayuran, daging, atau bumbu.")
        }
    }

    private var cameraBoxHeight: CGFloat {
        UIScreen.main.bounds.height * 0.58
    }

    // MARK: - Capture

    private func triggerCapture() {
        guard capturedPreview == nil else { return }
        cameraManager.capturePhoto()
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    cameraManager.stopSession()
                    capturedPreview = image
                    capturedImage = image
                    analyzeImage(image)
                }
            }
        }
    }

    private func analyzeImage(_ image: UIImage) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let items = try await GeminiService.getMenuRecommendations(from: image)
                await MainActor.run {
                    isLoading = false
                    onComplete(items)
                }
            } catch GeminiError.notFood {
                await MainActor.run {
                    isLoading = false
                    capturedPreview = nil
                    capturedImage = nil
                    cameraManager.startSession()
                    showNotFoodAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

