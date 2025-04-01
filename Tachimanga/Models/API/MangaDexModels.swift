import Foundation

// MangaDex API response models
struct MangaDexResponse<T: Codable>: Codable {
    let result: String
    let response: String
    let data: T
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaDexManga: Codable {
    let id: String
    let type: String
    let attributes: MangaDexMangaAttributes
    let relationships: [MangaDexRelationship]
}

struct MangaDexMangaAttributes: Codable {
    let title: [String: String]
    let altTitles: [[String: String]]
    let description: [String: String]
    let isLocked: Bool
    let links: [String: String]?
    let originalLanguage: String
    let lastVolume: String?
    let lastChapter: String?
    let publicationDemographic: String?
    let status: String
    let year: Int?
    let contentRating: String
    let tags: [MangaDexTag]
    let createdAt: String
    let updatedAt: String
    let version: Int
}

struct MangaDexTag: Codable {
    let id: String
    let type: String
    let attributes: MangaDexTagAttributes
}

struct MangaDexTagAttributes: Codable {
    let name: [String: String]
    let group: String
}

struct MangaDexRelationship: Codable {
    let id: String
    let type: String
    let attributes: MangaDexCoverArtAttributes?
}

struct MangaDexCoverArtAttributes: Codable {
    let fileName: String?
}
