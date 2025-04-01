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
    // Add new methods for favorites and reading progress
    func markChapterAsRead(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error>
    func markChapterAsUnread(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error>
    func getLastReadInfo(mangaId: String) -> AnyPublisher<(chapterId: String, page: Int)?, Error>
    func getReadChapters(mangaId: String) -> AnyPublisher<[String], Error>
    func clearReadingHistory() -> AnyPublisher<Void, Error>
    func getRecentlyReadManga(limit: Int) -> AnyPublisher<[Manga], Error>
}

class MockMangaRepository: MangaRepository {
    private var favorites: [String] = ["sample1"]
    var mangaDatabase: [Manga] = Manga.samples
    private var readingHistory: [ReadingHistoryEntry] = []
    private var readChapters: [String: [String]] = [:] // [mangaId: [chapterId]] mapping
    
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
                
                // Add to read chapters list
                if readChapters[mangaId] == nil {
                    readChapters[mangaId] = []
                }
                if !readChapters[mangaId]!.contains(chapterId) {
                    readChapters[mangaId]!.append(chapterId)
                }
                
                // Update the manga in database to mark chapter as read
                if let mangaIndex = mangaDatabase.firstIndex(where: { $0.id == mangaId }),
                   let chapterIndex = mangaDatabase[mangaIndex].chapters.firstIndex(where: { $0.id == chapterId }) {
                    mangaDatabase[mangaIndex].chapters[chapterIndex].isRead = true
                }
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
        
        // Update manga's last read information
        if let mangaIndex = mangaDatabase.firstIndex(where: { $0.id == mangaId }) {
            mangaDatabase[mangaIndex].lastReadChapter = chapterId
            mangaDatabase[mangaIndex].lastReadPage = page
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
    
    // Implement new methods
    
    func markChapterAsRead(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        // Add to read chapters list
        if readChapters[mangaId] == nil {
            readChapters[mangaId] = []
        }
        if !readChapters[mangaId]!.contains(chapterId) {
            readChapters[mangaId]!.append(chapterId)
        }
        
        // Update the manga in database
        if let mangaIndex = mangaDatabase.firstIndex(where: { $0.id == mangaId }),
           let chapterIndex = mangaDatabase[mangaIndex].chapters.firstIndex(where: { $0.id == chapterId }) {
            mangaDatabase[mangaIndex].chapters[chapterIndex].isRead = true
        }
        
        // Create history entry if it doesn't exist
        if !readingHistory.contains(where: { $0.mangaId == mangaId && $0.chapterId == chapterId }) {
            let entry = ReadingHistoryEntry(
                mangaId: mangaId,
                chapterId: chapterId,
                lastPageRead: 0,
                dateAccessed: Date(),
                isCompleted: true
            )
            readingHistory.append(entry)
        } else {
            // Update existing entry
            if let index = readingHistory.firstIndex(where: { $0.mangaId == mangaId && $0.chapterId == chapterId }) {
                readingHistory[index].isCompleted = true
                readingHistory[index].dateAccessed = Date()
            }
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func markChapterAsUnread(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        // Remove from read chapters
        if var chapters = readChapters[mangaId] {
            chapters.removeAll { $0 == chapterId }
            readChapters[mangaId] = chapters
        }
        
        // Update manga in database
        if let mangaIndex = mangaDatabase.firstIndex(where: { $0.id == mangaId }),
           let chapterIndex = mangaDatabase[mangaIndex].chapters.firstIndex(where: { $0.id == chapterId }) {
            mangaDatabase[mangaIndex].chapters[chapterIndex].isRead = false
        }
        
        // Remove completed status from history
        if let index = readingHistory.firstIndex(where: { $0.mangaId == mangaId && $0.chapterId == chapterId }) {
            readingHistory[index].isCompleted = false
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLastReadInfo(mangaId: String) -> AnyPublisher<(chapterId: String, page: Int)?, Error> {
        // Get the most recent history entry for this manga
        let entries = readingHistory.filter { $0.mangaId == mangaId }
        let sortedEntries = entries.sorted(by: { $0.dateAccessed > $1.dateAccessed })
        
        if let latestEntry = sortedEntries.first {
            return Just((chapterId: latestEntry.chapterId, page: latestEntry.lastPageRead))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func getReadChapters(mangaId: String) -> AnyPublisher<[String], Error> {
        return Just(readChapters[mangaId] ?? [])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func clearReadingHistory() -> AnyPublisher<Void, Error> {
        readingHistory.removeAll()
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRecentlyReadManga(limit: Int) -> AnyPublisher<[Manga], Error> {
        // Group by manga and sort by most recent access
        let mangaIds = Array(Set(readingHistory.map { $0.mangaId }))
        
        let recentMangaIds = mangaIds.sorted { mangaId1, mangaId2 in
            let latestDate1 = readingHistory
                .filter { $0.mangaId == mangaId1 }
                .map { $0.dateAccessed }
                .max() ?? Date.distantPast
            
            let latestDate2 = readingHistory
                .filter { $0.mangaId == mangaId2 }
                .map { $0.dateAccessed }
                .max() ?? Date.distantPast
            
            return latestDate1 > latestDate2
        }
        
        // Get manga objects for these IDs, limited to requested count
        let limitedIds = recentMangaIds.prefix(limit)
        let recentManga = mangaDatabase.filter { limitedIds.contains($0.id) }
            .sorted { manga1, manga2 in
                let index1 = limitedIds.firstIndex(of: manga1.id) ?? Int.max
                let index2 = limitedIds.firstIndex(of: manga2.id) ?? Int.max
                return index1 < index2
            }
        
        return Just(recentManga)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
