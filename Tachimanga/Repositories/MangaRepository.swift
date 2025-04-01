import Foundation
import Combine

protocol MangaRepository {
    func fetchPopularManga() -> AnyPublisher<[Manga], Error>
    func fetchMangaDetails(id: String) -> AnyPublisher<Manga, Error>
    func searchManga(query: String) -> AnyPublisher<[Manga], Error>
    func fetchChapterPages(mangaId: String, chapterId: String) -> AnyPublisher<[URL], Error>
    func toggleFavorite(mangaId: String) -> AnyPublisher<Bool, Error>
    func getFavorites() -> AnyPublisher<[Manga], Error>
    func updateReadingProgress(mangaId: String, chapterId: String, page: Int) -> AnyPublisher<Void, Error>
    func getReadingHistory() -> AnyPublisher<[ReadingHistoryEntry], Error>
    // New methods for enhanced catalog functionality
    func fetchMangaByGenre(genres: [String]) -> AnyPublisher<[Manga], Error>
}

class MockMangaRepository: MangaRepository {
    private var favorites: [String] = ["sample1"]
    private var mangaDatabase: [Manga] = Manga.samples
    private var readingHistory: [ReadingHistoryEntry] = []
    
    func fetchPopularManga() -> AnyPublisher<[Manga], Error> {
        Just(mangaDatabase)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchMangaDetails(id: String) -> AnyPublisher<Manga, Error> {
        guard let manga = mangaDatabase.first(where: { $0.id == id }) else {
            return Fail(error: NSError(domain: "MangaRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Manga not found"]))
                .eraseToAnyPublisher()
        }
        
        var mangaWithFavoriteStatus = manga
        mangaWithFavoriteStatus.isFavorite = favorites.contains(id)
        
        return Just(mangaWithFavoriteStatus)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func searchManga(query: String) -> AnyPublisher<[Manga], Error> {
        let results = mangaDatabase.filter { 
            $0.title.lowercased().contains(query.lowercased()) || 
            $0.author.lowercased().contains(query.lowercased()) ||
            $0.genres.contains(where: { $0.lowercased().contains(query.lowercased()) })
        }
        
        return Just(results)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchChapterPages(mangaId: String, chapterId: String) -> AnyPublisher<[URL], Error> {
        let sampleURLs = (1...10).compactMap { URL(string: "https://example.com/manga/\(mangaId)/\(chapterId)/\($0).jpg") }
        
        // Add to reading history
        let historyEntry = ReadingHistoryEntry(
            mangaId: mangaId,
            chapterId: chapterId,
            lastPageRead: 0,
            dateAccessed: Date(),
            isCompleted: false
        )
        
        if let existingIndex = readingHistory.firstIndex(where: { $0.mangaId == mangaId && $0.chapterId == chapterId }) {
            readingHistory[existingIndex].dateAccessed = Date()
        } else {
            readingHistory.append(historyEntry)
        }
        
        return Just(sampleURLs)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func toggleFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        if favorites.contains(mangaId) {
            favorites.removeAll { $0 == mangaId }
            return Just(false)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            favorites.append(mangaId)
            return Just(true)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func getFavorites() -> AnyPublisher<[Manga], Error> {
        let favoriteManga = mangaDatabase.filter { favorites.contains($0.id) }
        return Just(favoriteManga)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateReadingProgress(mangaId: String, chapterId: String, page: Int) -> AnyPublisher<Void, Error> {
        if let index = readingHistory.firstIndex(where: { $0.mangaId == mangaId && $0.chapterId == chapterId }) {
            readingHistory[index].lastPageRead = page
            readingHistory[index].dateAccessed = Date()
            
            // Mark as completed if it's the last page
            if let manga = mangaDatabase.first(where: { $0.id == mangaId }),
               let chapter = manga.chapters.first(where: { $0.id == chapterId }),
               page >= chapter.pageCount - 1 {
                readingHistory[index].isCompleted = true
            }
        } else {
            let entry = ReadingHistoryEntry(
                mangaId: mangaId, 
                chapterId: chapterId, 
                lastPageRead: page,
                dateAccessed: Date(),
                isCompleted: false
            )
            readingHistory.append(entry)
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getReadingHistory() -> AnyPublisher<[ReadingHistoryEntry], Error> {
        return Just(readingHistory.sorted(by: { $0.dateAccessed > $1.dateAccessed }))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchMangaByGenre(genres: [String]) -> AnyPublisher<[Manga], Error> {
        let filteredManga = mangaDatabase.filter { manga in
            !Set(manga.genres).isDisjoint(with: Set(genres))
        }
        
        return Just(filteredManga)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
