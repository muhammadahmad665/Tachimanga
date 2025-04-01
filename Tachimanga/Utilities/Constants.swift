import Foundation
import SwiftUI

enum AppConstants {
    static let appName = "Tachimanga"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    enum API {
        static let baseURL = "https://api.example.com"
        static let apiKey = "YOUR_API_KEY" // In production, load from secure storage
    }
    
    enum Storage {
        static let userPreferencesKey = "user_preferences"
        static let favoritesMangaKey = "favorites_manga"
        static let readingHistoryKey = "reading_history"
    }
    
    enum UI {
        static let cornerRadius: CGFloat = 8
        static let defaultPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let primaryColor = Color.blue
        static let secondaryColor = Color.orange
        static let errorColor = Color.red
    }
}
