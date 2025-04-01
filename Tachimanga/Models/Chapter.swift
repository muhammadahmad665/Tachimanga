import Foundation

struct Chapter: Identifiable, Codable, Equatable {
    let id: String
    let mangaId: String
    let number: Double
    let title: String?
    let dateReleased: Date
    let pageCount: Int
    var isRead: Bool
    let pageUrls: [URL]?
    
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id && lhs.mangaId == rhs.mangaId
    }
    
    // For preview/testing
    static var sample: Chapter {
        Chapter(
            id: "chapter1",
            mangaId: "sample1",
            number: 1.0,
            title: "Romance Dawn",
            dateReleased: Date(),
            pageCount: 45,
            isRead: false,
            pageUrls: nil
        )
    }
}
