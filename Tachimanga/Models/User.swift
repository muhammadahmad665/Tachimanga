import Foundation

struct User: Codable {
    var id: String
    var username: String
    var email: String?
    var favorites: [String] = [] // Manga IDs
    var readingHistory: [ReadingHistoryEntry] = []
    var preferences: UserPreferences = UserPreferences()
    
    static var sample: User {
        User(
            id: "user1",
            username: "manga_fan",
            email: "user@example.com",
            favorites: ["sample1"]
        )
    }
}

struct ReadingHistoryEntry: Codable, Identifiable {
    var id: String { mangaId + chapterId }
    var mangaId: String
    var chapterId: String
    var lastPageRead: Int
    var dateAccessed: Date
    var isCompleted: Bool
}

struct UserPreferences: Codable {
    var readerDirection: ReaderDirection = .leftToRight
    var darkMode: Bool = false
    var autoUpdateManga: Bool = true
    var notificationsEnabled: Bool = true
    var dataSavingMode: Bool = false
    var downloadOnlyOnWifi: Bool = true
    
    // Reader-specific settings
    var hideStatusBarInReader: Bool = true
    var keepScreenOnDuringReading: Bool = true
    var defaultZoomMode: String = ZoomScale.fitToScreen.rawValue
    var showPageNumber: Bool = true
    var preloadNextChapter: Bool = true
}

enum ReaderDirection: String, Codable, CaseIterable {
    case leftToRight = "Left to Right"
    case rightToLeft = "Right to Left"
    case vertical = "Vertical"
}
