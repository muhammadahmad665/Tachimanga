//
//  TachimangaApp.swift
//  Tachimanga
//
//  Created by ahmed on 02/04/2025.
//

import SwiftUI

@main
struct TachimangaApp: App {
    // Register services at app startup
    let serviceProvider = ServiceProvider.shared
    
    init() {
        // Configure app for compatibility
        setupAppCompatibility()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceProvider)
        }
    }
    
    private func setupAppCompatibility() {
        // Force light mode if needed for compatibility
        if #available(iOS 15.0, *) {
            // Modern iOS can use either mode
        } else {
            // Force light mode on older iOS
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
        }
    }
}
