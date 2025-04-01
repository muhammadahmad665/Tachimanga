import Foundation

struct Manga: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let coverImageURL: URL?
    var author: String
    var description: String
    var genres: [String]
    var status: MangaStatus
    var chapters: [Chapter]
    var isFavorite: Bool = false
    var lastReadChapter: String? = nil
    var lastReadPage: Int = 0
    var dateAdded: Date = Date()
    
    static func == (lhs: Manga, rhs: Manga) -> Bool {
        lhs.id == rhs.id
    }
    
    // For preview/testing
    static var sample: Manga {
        Manga(
            id: "sample1",
            title: "One Piece",
            coverImageURL: URL(string: "https://example.com/onepiece.jpg"),
            author: "Eiichiro Oda",
            description: "The story follows the adventures of Monkey D. Luffy, a boy whose body gained the properties of rubber after unintentionally eating a Devil Fruit.",
            genres: ["Action", "Adventure", "Fantasy"],
            status: .ongoing,
            chapters: [Chapter.sample]
        )
    }
    
    static var samples: [Manga] {
        [
            Manga.sample,
            Manga(
                id: "sample2",
                title: "Berserk",
                coverImageURL: URL(string: "https://example.com/berserk.jpg"),
                author: "Kentaro Miura",
                description: "Guts, a former mercenary now known as the 'Black Swordsman', seeks revenge against his former friend Griffith, who sacrificed his friends to become a powerful demon.",
                genres: ["Action", "Adventure", "Dark Fantasy", "Horror"],
                status: .ongoing,
                chapters: [Chapter.sample]
            ),
            Manga(
                id: "sample3",
                title: "Attack on Titan",
                coverImageURL: URL(string: "https://example.com/aot.jpg"),
                author: "Hajime Isayama",
                description: "In a world where humanity lives inside cities surrounded by enormous walls due to the Titans, gigantic humanoid creatures who devour humans seemingly without reason.",
                genres: ["Action", "Dark Fantasy", "Post-Apocalyptic"],
                status: .completed,
                chapters: [Chapter.sample]
            )
        ]
    }
}

// Make MangaStatus conform to CaseIterable directly in the same file
enum MangaStatus: String, Codable, CaseIterable {
    case ongoing = "Ongoing"
    case completed = "Completed"
    case hiatus = "Hiatus"
    case cancelled = "Cancelled"
}
