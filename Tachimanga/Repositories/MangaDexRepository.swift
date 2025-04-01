import Foundation
import Combine

class MangaDexRepository: MangaRepository {
    private let apiService: APIService
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // Private state for source management
    private var currentSource: MangaSource = MangaSource(id: "mangadex", name: "MangaDex", icon: "book.closed.fill")
    private var availableSources: [MangaSource] = [
        MangaSource(id: "mangadex", name: "MangaDex", icon: "book.closed.fill"),
        MangaSource(id: "mock", name: "Mock Source", icon: "book.fill"),
        MangaSource(id: "mangakakalot", name: "Mangakakalot", icon: "book.closed")
    ]
    
    init(apiService: APIService, databaseService: DatabaseService) {
        self.apiService = apiService
        self.databaseService = databaseService
    }
    
    func fetchPopularManga() -> AnyPublisher<[Manga], Error> {
        let parameters: [String: Any] = [
            "limit": 20,
            "order[rating]": "desc",
            "includes[]": "cover_art",
            "contentRating[]": "safe",
            "contentRating[]": "suggestive",
            "hasAvailableChapters": true
        ]
        
        return apiService.fetch(endpoint: "/manga", parameters: parameters)
            .map { (response: MangaDexResponse<[MangaDexManga]>) in
                response.data.compactMap { self.convertToManga($0) }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchMangaDetails(id: String) -> AnyPublisher<Manga, Error> {
        let parameters: [String: Any] = [
            "includes[]": "cover_art",
            "includes[]": "author"
        ]
        
        return apiService.fetch(endpoint: "/manga/\(id)", parameters: parameters)
            .tryMap { (response: MangaDexResponse<MangaDexManga>) in
                guard let manga = self.convertToManga(response.data) else {
                    throw NSError(domain: "MangaDexRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to parse manga details"])
                }
                return manga
            }
            .eraseToAnyPublisher()
    }
    
    func searchManga(query: String) -> AnyPublisher<[Manga], Error> {
        let parameters: [String: Any] = [
            "limit": 20,
            "title": query,
            "includes[]": "cover_art",
            "contentRating[]": "safe",
            "contentRating[]": "suggestive",
            "hasAvailableChapters": true
        ]
        
        return apiService.fetch(endpoint: "/manga", parameters: parameters)
            .map { (response: MangaDexResponse<[MangaDexManga]>) in
                response.data.compactMap { self.convertToManga($0) }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchMangaByGenre(genres: [String]) -> AnyPublisher<[Manga], Error> {
        var parameters: [String: Any] = [
            "limit": 20,
            "includes[]": "cover_art",
            "contentRating[]": "safe",
            "contentRating[]": "suggestive",
            "hasAvailableChapters": true
        ]
        
        // Add genre IDs to parameters
        for (index, genre) in genres.enumerated() {
            parameters["includedTags[\(index)]"] = genre
        }
        
        return apiService.fetch(endpoint: "/manga", parameters: parameters)
            .map { (response: MangaDexResponse<[MangaDexManga]>) in
                response.data.compactMap { self.convertToManga($0) }
            }
            .eraseToAnyPublisher()
    }
    
    // Functions required by MangaRepository protocol
    func fetchChapterPages(mangaId: String, chapterId: String) -> AnyPublisher<[URL], Error> {
        // Implementation will be added later
        return MockMangaRepository().fetchChapterPages(mangaId: mangaId, chapterId: chapterId)
    }
    
    func toggleFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        // Implementation using local database
        return MockMangaRepository().toggleFavorite(mangaId: mangaId)
    }
    
    func getFavorites() -> AnyPublisher<[Manga], Error> {
        // Implementation using local database
        return MockMangaRepository().getFavorites()
    }
    
    func updateReadingProgress(mangaId: String, chapterId: String, page: Int) -> AnyPublisher<Void, Error> {
        // Implementation using local database
        return MockMangaRepository().updateReadingProgress(mangaId: mangaId, chapterId: chapterId, page: page)
    }
    
    func getReadingHistory() -> AnyPublisher<[ReadingHistoryEntry], Error> {
        // Implementation using local database
        return MockMangaRepository().getReadingHistory()
    }
    
    // Implement new methods
    func markChapterAsRead(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        return MockMangaRepository().markChapterAsRead(mangaId: mangaId, chapterId: chapterId)
    }
    
    func markChapterAsUnread(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        return MockMangaRepository().markChapterAsUnread(mangaId: mangaId, chapterId: chapterId)
    }
    
    func getLastReadInfo(mangaId: String) -> AnyPublisher<(chapterId: String, page: Int)?, Error> {
        return MockMangaRepository().getLastReadInfo(mangaId: mangaId)
    }
    
    func getReadChapters(mangaId: String) -> AnyPublisher<[String], Error> {
        return MockMangaRepository().getReadChapters(mangaId: mangaId)
    }
    
    func clearReadingHistory() -> AnyPublisher<Void, Error> {
        return MockMangaRepository().clearReadingHistory()
    }
    
    func getRecentlyReadManga(limit: Int) -> AnyPublisher<[Manga], Error> {
        return MockMangaRepository().getRecentlyReadManga(limit: limit)
    }
    
    func fetchMangaWithFilters(
        genres: [String]?,
        status: [MangaStatus]?,
        languages: [String]?,
        sortOption: MangaSortOption,
        page: Int,
        itemsPerPage: Int
    ) -> AnyPublisher<MangaPage, Error> {
        // Create parameters dictionary with single key-value pairs first
        var parameters: [String: Any] = [
            "limit": itemsPerPage,
            "offset": (page - 1) * itemsPerPage,
            "includes[]": "cover_art",
            "hasAvailableChapters": true
        ]
        
        // Add content ratings (can have multiple values) as an array
        let contentRatings = ["safe", "suggestive"]
        for (index, rating) in contentRatings.enumerated() {
            parameters["contentRating[\(index)]"] = rating
        }
        
        // Add genre filter
        if let genres = genres {
            for (index, genre) in genres.enumerated() {
                parameters["includedTags[\(index)]"] = genre
            }
        }
        
        // Add status filter
        if let status = status {
            for (index, statusValue) in status.enumerated() {
                // Convert MangaStatus enum to MangaDex status values
                let mangaDexStatus: String
                switch statusValue {
                case .ongoing:
                    mangaDexStatus = "ongoing"
                case .completed:
                    mangaDexStatus = "completed"
                case .hiatus:
                    mangaDexStatus = "hiatus"
                case .cancelled:
                    mangaDexStatus = "cancelled"
                }
                parameters["status[\(index)]"] = mangaDexStatus
            }
        }
        
        // Add language filter
        if let languages = languages {
            for (index, language) in languages.enumerated() {
                // Convert language names to MangaDex language codes
                let languageCode = convertToLanguageCode(language)
                parameters["originalLanguage[\(index)]"] = languageCode
            }
        }
        
        // Add sort parameter
        switch sortOption {
        case .alphabetical:
            parameters["order[title]"] = "asc"
        case .popularity:
            parameters["order[rating]"] = "desc"
        case .releaseDate:
            parameters["order[year]"] = "desc"
        case .latestUpdate:
            parameters["order[latestUploadedChapter]"] = "desc"
        }
        
        return apiService.fetch(endpoint: "/manga", parameters: parameters)
            .map { (response: MangaDexResponse<[MangaDexManga]>) in
                let manga = response.data.compactMap { self.convertToManga($0) }
                
                return MangaPage(
                    manga: manga,
                    currentPage: page,
                    totalPages: Int(ceil(Double(response.total) / Double(itemsPerPage))),
                    hasNextPage: (page * itemsPerPage) < response.total
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getAvailableFilters() -> AnyPublisher<MangaFilterOptions, Error> {
        // In a full implementation, we would fetch tags from the MangaDex API
        // For now, we'll use a static list
        
        // Get actual genres from MangaDex
        return apiService.fetch(endpoint: "/manga/tag", parameters: nil)
            .compactMap { (response: MangaDexResponse<[MangaDexTag]>) -> MangaFilterOptions in
                let genres = response.data
                    .filter { $0.attributes.group == "genre" }
                    .compactMap { $0.attributes.name["en"] }
                    .sorted()
                
                let languages = ["English", "Japanese", "Korean", "Chinese", "French", "Spanish"]
                
                return MangaFilterOptions(
                    genres: genres,
                    status: MangaStatus.allCases,
                    languages: languages,
                    sortOptions: MangaSortOption.allCases
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getAvailableSources() -> AnyPublisher<[MangaSource], Error> {
        return Just(availableSources)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func switchSource(sourceId: String) -> AnyPublisher<Bool, Error> {
        if let newSource = availableSources.first(where: { $0.id == sourceId }) {
            currentSource = newSource
            return Just(true)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: NSError(
            domain: "MangaRepository", 
            code: 404, 
            userInfo: [NSLocalizedDescriptionKey: "Source not found"]
        ))
        .eraseToAnyPublisher()
    }
    
    func getCurrentSource() -> AnyPublisher<MangaSource, Error> {
        return Just(currentSource)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // Helper to convert human-readable language names to ISO codes
    private func convertToLanguageCode(_ language: String) -> String {
        switch language.lowercased() {
        case "english":
            return "en"
        case "japanese":
            return "ja"
        case "korean":
            return "ko"
        case "chinese":
            return "zh"
        case "french":
            return "fr"
        case "spanish":
            return "es"
        default:
            return "en"
        }
    }
    
    // Helper methods for API data conversion
    private func convertToManga(_ mangaDexManga: MangaDexManga) -> Manga? {
        // Extract title (preferably in English)
        guard let title = mangaDexManga.attributes.title["en"] ?? mangaDexManga.attributes.title.values.first else {
            return nil
        }
        
        // Extract description
        let description = mangaDexManga.attributes.description["en"] ?? mangaDexManga.attributes.description.values.first ?? ""
        
        // Extract cover image URL
        var coverImageURL: URL?
        if let coverArtRelationship = mangaDexManga.relationships.first(where: { $0.type == "cover_art" }),
           let fileName = coverArtRelationship.attributes?.fileName {
            coverImageURL = URL(string: "https://uploads.mangadex.org/covers/\(mangaDexManga.id)/\(fileName)")
        }
        
        // Extract author
        let author = "Unknown" // Would need to parse from relationships if available
        
        // Extract genres
        let genres = mangaDexManga.attributes.tags
            .filter { $0.attributes.group == "genre" }
            .compactMap { $0.attributes.name["en"] }
        
        // Map status
        let status: MangaStatus
        switch mangaDexManga.attributes.status {
        case "ongoing":
            status = .ongoing
        case "completed":
            status = .completed
        case "hiatus":
            status = .hiatus
        default:
            status = .ongoing
        }
        
        return Manga(
            id: mangaDexManga.id,
            title: title,
            coverImageURL: coverImageURL,
            author: author,
            description: description,
            genres: genres,
            status: status,
            chapters: [] // Chapters would need to be fetched separately
        )
    }
}
