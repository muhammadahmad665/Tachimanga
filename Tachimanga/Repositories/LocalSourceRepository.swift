import Foundation
import Combine
import UIKit

class LocalSourceRepository: MangaRepository {
    private let fileManager = FileManager.default
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // Local storage paths
    private let documentDirectory: URL
    private let mangaDirectory: URL
    private var currentSource: MangaSource
    
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        
        // Set up directory paths
        self.documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.mangaDirectory = documentDirectory.appendingPathComponent("Manga", isDirectory: true)
        
        // Create local source entry
        self.currentSource = MangaSource(id: "local", name: "Local Source", icon: "folder.fill")
        
        // Ensure manga directory exists
        try? fileManager.createDirectory(at: mangaDirectory, withIntermediateDirectories: true)
    }
    
    func fetchPopularManga() -> AnyPublisher<[Manga], Error> {
        // For local source, "popular" is just all local manga
        return getAllLocalManga()
    }
    
    func fetchMangaDetails(id: String) -> AnyPublisher<Manga, Error> {
        return getLocalManga(id: id)
            .flatMap { manga -> AnyPublisher<Manga, Error> in
                // Get favorite status from database
                return self.isFavorite(mangaId: id)
                    .map { isFavorite in
                        var updatedManga = manga
                        updatedManga.isFavorite = isFavorite
                        return updatedManga
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func searchManga(query: String) -> AnyPublisher<[Manga], Error> {
        return getAllLocalManga()
            .map { allManga in
                allManga.filter { manga in
                    query.isEmpty || 
                    manga.title.localizedCaseInsensitiveContains(query) ||
                    manga.author.localizedCaseInsensitiveContains(query) ||
                    manga.genres.contains { genre in
                        genre.localizedCaseInsensitiveContains(query)
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchChapterPages(mangaId: String, chapterId: String) -> AnyPublisher<[URL], Error> {
        let chapterDirectory = mangaDirectory
            .appendingPathComponent(mangaId, isDirectory: true)
            .appendingPathComponent(chapterId, isDirectory: true)
        
        guard fileManager.fileExists(atPath: chapterDirectory.path) else {
            return Fail(error: NSError(domain: "LocalSourceRepository", 
                                      code: 404, 
                                      userInfo: [NSLocalizedDescriptionKey: "Chapter directory not found"]))
                .eraseToAnyPublisher()
        }
        
        do {
            // Get all image files in the chapter directory, sorted numerically
            let files = try fileManager.contentsOfDirectory(at: chapterDirectory, 
                                                           includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "jpg" || 
                          $0.pathExtension.lowercased() == "png" ||
                          $0.pathExtension.lowercased() == "jpeg" }
                .sorted { 
                    // Sort files numerically (page001.jpg, page002.jpg, etc.)
                    let name1 = $0.deletingPathExtension().lastPathComponent
                    let name2 = $1.deletingPathExtension().lastPathComponent
                    return name1.localizedStandardCompare(name2) == .orderedAscending
                }
            
            // Create history entry
            self.addToReadingHistory(mangaId: mangaId, chapterId: chapterId)
            
            return Just(files)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        // First check current status
        return isFavorite(mangaId: mangaId)
            .flatMap { isFavorite -> AnyPublisher<Bool, Error> in
                if isFavorite {
                    // Remove from favorites
                    return self.removeFavorite(mangaId: mangaId)
                } else {
                    // Add to favorites
                    return self.addFavorite(mangaId: mangaId)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func isFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        return databaseService.load(key: "favorites")
            .map { (favorites: [String]?) -> Bool in
                return favorites?.contains(mangaId) ?? false
            }
            .catch { _ in
                // If there's an error loading favorites, assume it's not a favorite
                return Just(false).setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    private func addFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        return databaseService.load(key: "favorites")
            .flatMap { (favorites: [String]?) -> AnyPublisher<Bool, Error> in
                var updatedFavorites = favorites ?? []
                updatedFavorites.append(mangaId)
                
                return self.databaseService.save(object: updatedFavorites, key: "favorites")
                    .map { _ in true }
                    .eraseToAnyPublisher()
            }
            .catch { _ in
                // If there's an error, create a new favorites list with this manga
                return self.databaseService.save(object: [mangaId], key: "favorites")
                    .map { _ in true }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func removeFavorite(mangaId: String) -> AnyPublisher<Bool, Error> {
        return databaseService.load(key: "favorites")
            .flatMap { (favorites: [String]?) -> AnyPublisher<Bool, Error> in
                var updatedFavorites = favorites ?? []
                updatedFavorites.removeAll { $0 == mangaId }
                
                return self.databaseService.save(object: updatedFavorites, key: "favorites")
                    .map { _ in false }
                    .eraseToAnyPublisher()
            }
            .catch { _ in
                // If there's an error, just return false
                return Just(false)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func getFavorites() -> AnyPublisher<[Manga], Error> {
        return databaseService.load(key: "favorites")
            .flatMap { (favoriteIds: [String]?) -> AnyPublisher<[Manga], Error> in
                guard let favoriteIds = favoriteIds, !favoriteIds.isEmpty else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // Get all manga and filter by favorites
                return self.getAllLocalManga()
                    .map { allManga in
                        var favorites = allManga.filter { favoriteIds.contains($0.id) }
                        // Mark them as favorites
                        for i in 0..<favorites.count {
                            favorites[i].isFavorite = true
                        }
                        return favorites
                    }
                    .eraseToAnyPublisher()
            }
            .catch { _ in
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Reading Progress
    
    func updateReadingProgress(mangaId: String, chapterId: String, page: Int) -> AnyPublisher<Void, Error> {
        return getLocalManga(id: mangaId)
            .flatMap { manga -> AnyPublisher<Void, Error> in
                let progressEntry = ReadingProgress(
                    mangaId: mangaId,
                    chapterId: chapterId, 
                    page: page, 
                    dateAccessed: Date(), 
                    isCompleted: self.isLastPage(manga: manga, chapterId: chapterId, page: page)
                )
                
                return self.saveReadingProgress(progress: progressEntry)
            }
            .eraseToAnyPublisher()
    }
    
    private func isLastPage(manga: Manga, chapterId: String, page: Int) -> Bool {
        guard let chapter = manga.chapters.first(where: { $0.id == chapterId }) else {
            return false
        }
        
        return page >= chapter.pageCount - 1
    }
    
    private func saveReadingProgress(progress: ReadingProgress) -> AnyPublisher<Void, Error> {
        return databaseService.load(key: "reading_progress")
            .flatMap { (allProgress: [ReadingProgress]?) -> AnyPublisher<Void, Error> in
                var updatedProgress = allProgress ?? []
                
                // Remove existing entry if found
                updatedProgress.removeAll { 
                    $0.mangaId == progress.mangaId && $0.chapterId == progress.chapterId
                }
                
                // Add new entry
                updatedProgress.append(progress)
                
                // Update manga's last read info
                return self.updateMangaLastRead(mangaId: progress.mangaId, 
                                              chapterId: progress.chapterId, 
                                              page: progress.page)
                    .flatMap { _ in
                        // Save all progress
                        return self.databaseService.save(object: updatedProgress, key: "reading_progress")
                    }
                    .eraseToAnyPublisher()
            }
            .catch { _ in
                // If there's an error, create a new progress list
                return self.databaseService.save(object: [progress], key: "reading_progress")
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func updateMangaLastRead(mangaId: String, chapterId: String, page: Int) -> AnyPublisher<Void, Error> {
        return getLocalManga(id: mangaId)
            .flatMap { manga -> AnyPublisher<Void, Error> in
                var updatedManga = manga
                updatedManga.lastReadChapter = chapterId
                updatedManga.lastReadPage = page
                
                let mangaPath = self.mangaDirectory.appendingPathComponent("\(mangaId)/info.json")
                do {
                    let data = try JSONEncoder().encode(updatedManga)
                    try data.write(to: mangaPath)
                    return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getReadingHistory() -> AnyPublisher<[ReadingHistoryEntry], Error> {
        return databaseService.load(key: "reading_progress")
            .map { (allProgress: [ReadingProgress]?) -> [ReadingHistoryEntry] in
                let progress = allProgress ?? []
                
                // Convert to ReadingHistoryEntry
                return progress.map { 
                    ReadingHistoryEntry(
                        mangaId: $0.mangaId, 
                        chapterId: $0.chapterId, 
                        lastPageRead: $0.page, 
                        dateAccessed: $0.dateAccessed, 
                        isCompleted: $0.isCompleted
                    ) 
                }
                .sorted(by: { $0.dateAccessed > $1.dateAccessed })
            }
            .catch { _ in
                return Just([]).setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    private func addToReadingHistory(mangaId: String, chapterId: String) {
        // Just create an entry with page 0
        let progress = ReadingProgress(
            mangaId: mangaId,
            chapterId: chapterId,
            page: 0,
            dateAccessed: Date(),
            isCompleted: false
        )
        
        _ = saveReadingProgress(progress: progress)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Marking Chapters Read/Unread
    
    func markChapterAsRead(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        return getLocalManga(id: mangaId)
            .flatMap { manga -> AnyPublisher<Void, Error> in
                guard let chapter = manga.chapters.first(where: { $0.id == chapterId }) else {
                    return Fail(error: NSError(domain: "LocalSourceRepository", 
                                             code: 404, 
                                             userInfo: [NSLocalizedDescriptionKey: "Chapter not found"]))
                        .eraseToAnyPublisher()
                }
                
                let progress = ReadingProgress(
                    mangaId: mangaId,
                    chapterId: chapterId,
                    page: chapter.pageCount - 1, // Last page
                    dateAccessed: Date(),
                    isCompleted: true
                )
                
                return self.saveReadingProgress(progress: progress)
            }
            .flatMap { _ -> AnyPublisher<Void, Error> in
                return self.updateMangaChapterReadStatus(mangaId: mangaId, chapterId: chapterId, isRead: true)
            }
            .eraseToAnyPublisher()
    }
    
    func markChapterAsUnread(mangaId: String, chapterId: String) -> AnyPublisher<Void, Error> {
        return databaseService.load(key: "reading_progress")
            .flatMap { (allProgress: [ReadingProgress]?) -> AnyPublisher<Void, Error> in
                var updatedProgress = allProgress ?? []
                
                // Update the entry to be not completed
                if let index = updatedProgress.firstIndex(where: { 
                    $0.mangaId == mangaId && $0.chapterId == chapterId 
                }) {
                    updatedProgress[index].isCompleted = false
                }
                
                return self.databaseService.save(object: updatedProgress, key: "reading_progress")
            }
            .flatMap { _ -> AnyPublisher<Void, Error> in
                return self.updateMangaChapterReadStatus(mangaId: mangaId, chapterId: chapterId, isRead: false)
            }
            .eraseToAnyPublisher()
    }
    
    private func updateMangaChapterReadStatus(mangaId: String, chapterId: String, isRead: Bool) -> AnyPublisher<Void, Error> {
        return getLocalManga(id: mangaId)
            .flatMap { manga -> AnyPublisher<Void, Error> in
                var updatedManga = manga
                
                // Update chapter read status
                if let index = updatedManga.chapters.firstIndex(where: { $0.id == chapterId }) {
                    updatedManga.chapters[index].isRead = isRead
                }
                
                let mangaPath = self.mangaDirectory.appendingPathComponent("\(mangaId)/info.json")
                do {
                    let data = try JSONEncoder().encode(updatedManga)
                    try data.write(to: mangaPath)
                    return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getLastReadInfo(mangaId: String) -> AnyPublisher<(chapterId: String, page: Int)?, Error> {
        return databaseService.load(key: "reading_progress")
            .map { (allProgress: [ReadingProgress]?) -> (chapterId: String, page: Int)? in
                guard let allProgress = allProgress else { return nil }
                
                // Find all entries for this manga
                let mangaEntries = allProgress.filter { $0.mangaId == mangaId }
                
                // Get the most recent entry
                if let mostRecent = mangaEntries.max(by: { $0.dateAccessed < $1.dateAccessed }) {
                    return (chapterId: mostRecent.chapterId, page: mostRecent.page)
                }
                
                return nil
            }
            .catch { _ in
                return Just(nil).setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    func getReadChapters(mangaId: String) -> AnyPublisher<[String], Error> {
        return databaseService.load(key: "reading_progress")
            .map { (allProgress: [ReadingProgress]?) -> [String] in
                guard let allProgress = allProgress else { return [] }
                
                // Find all completed entries for this manga
                return allProgress
                    .filter { $0.mangaId == mangaId && $0.isCompleted }
                    .map { $0.chapterId }
            }
            .catch { _ in
                return Just([]).setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    func clearReadingHistory() -> AnyPublisher<Void, Error> {
        return databaseService.save(object: [ReadingProgress](), key: "reading_progress")
            .eraseToAnyPublisher()
    }
    
    func getRecentlyReadManga(limit: Int) -> AnyPublisher<[Manga], Error> {
        return getReadingHistory()
            .flatMap { history -> AnyPublisher<[Manga], Error> in
                // Get unique manga IDs from history, sorted by most recent
                let mangaIds = Array(NSOrderedSet(array: history.map { $0.mangaId })) as! [String]
                
                // Load all manga data
                return self.getAllLocalManga()
                    .map { allManga -> [Manga] in
                        // Filter and sort by the order in mangaIds
                        var recentManga = [Manga]()
                        
                        for id in mangaIds {
                            if let manga = allManga.first(where: { $0.id == id }) {
                                recentManga.append(manga)
                            }
                            
                            if recentManga.count >= limit {
                                break
                            }
                        }
                        
                        return recentManga
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Advanced Filtering
    
    func fetchMangaWithFilters(
        genres: [String]?, 
        status: [MangaStatus]?, 
        languages: [String]?,
        sortOption: MangaSortOption,
        page: Int,
        itemsPerPage: Int
    ) -> AnyPublisher<MangaPage, Error> {
        return getAllLocalManga()
            .map { allManga -> MangaPage in
                var filteredManga = allManga
                
                // Filter by genres
                if let genres = genres, !genres.isEmpty {
                    filteredManga = filteredManga.filter { manga in
                        !Set(manga.genres).isDisjoint(with: Set(genres))
                    }
                }
                
                // Filter by status
                if let status = status, !status.isEmpty {
                    filteredManga = filteredManga.filter { manga in
                        status.contains(manga.status)
                    }
                }
                
                // Sort based on option
                switch sortOption {
                case .alphabetical:
                    filteredManga.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                case .popularity:
                    // For local source, popularity could be based on reading history
                    filteredManga.sort { $0.dateAdded > $1.dateAdded }
                case .releaseDate:
                    filteredManga.sort { $0.dateAdded > $1.dateAdded }
                case .latestUpdate:
                    filteredManga.sort { manga1, manga2 in
                        let latestChapter1 = manga1.chapters.max { $0.dateReleased < $1.dateReleased }?.dateReleased ?? Date.distantPast
                        let latestChapter2 = manga2.chapters.max { $0.dateReleased < $1.dateReleased }?.dateReleased ?? Date.distantPast
                        return latestChapter1 > latestChapter2
                    }
                }
                
                // Pagination
                let total = filteredManga.count
                let start = (page - 1) * itemsPerPage
                let end = min(start + itemsPerPage, total)
                
                let paginatedManga = start < total ? Array(filteredManga[start..<end]) : []
                
                return MangaPage(
                    manga: paginatedManga,
                    currentPage: page,
                    totalPages: Int(ceil(Double(total) / Double(itemsPerPage))),
                    hasNextPage: end < total
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getAvailableFilters() -> AnyPublisher<MangaFilterOptions, Error> {
        return getAllLocalManga()
            .map { allManga -> MangaFilterOptions in
                // Extract all unique genres
                let genres = Array(Set(allManga.flatMap { $0.genres })).sorted()
                
                return MangaFilterOptions(
                    genres: genres,
                    status: MangaStatus.allCases,
                    languages: ["English"], // Local source assumes English
                    sortOptions: MangaSortOption.allCases
                )
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Source Management
    
    func getAvailableSources() -> AnyPublisher<[MangaSource], Error> {
        return Just([currentSource])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func switchSource(sourceId: String) -> AnyPublisher<Bool, Error> {
        // Local source is the only source, so we can't switch
        return Just(sourceId == currentSource.id)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getCurrentSource() -> AnyPublisher<MangaSource, Error> {
        return Just(currentSource)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchMangaByGenre(genres: [String]) -> AnyPublisher<[Manga], Error> {
        return getAllLocalManga()
            .map { allManga in
                allManga.filter { manga in
                    !Set(manga.genres).isDisjoint(with: Set(genres))
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Local Source Specific Methods
    
    /// Get all manga from local storage
    private func getAllLocalManga() -> AnyPublisher<[Manga], Error> {
        do {
            // Get all manga directories
            let mangaDirs = try fileManager.contentsOfDirectory(at: mangaDirectory, includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath }
            
            // If no manga found, return empty array
            if mangaDirs.isEmpty {
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            // Create publishers for each manga
            let mangaPublishers = mangaDirs.map { getLocalManga(directory: $0) }
            
            // Combine all publishers
            return Publishers.MergeMany(mangaPublishers)
                .collect()
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Get a specific manga by ID
    private func getLocalManga(id: String) -> AnyPublisher<Manga, Error> {
        let mangaDir = mangaDirectory.appendingPathComponent(id, isDirectory: true)
        return getLocalManga(directory: mangaDir)
    }
    
    /// Read manga data from a directory
    private func getLocalManga(directory: URL) -> AnyPublisher<Manga, Error> {
        let infoPath = directory.appendingPathComponent("info.json")
        
        guard fileManager.fileExists(atPath: infoPath.path) else {
            // No info file, try to create one from directory structure
            return createMangaInfoFromDirectory(directory: directory)
        }
        
        do {
            let data = try Data(contentsOf: infoPath)
            let manga = try JSONDecoder().decode(Manga.self, from: data)
            return Just(manga).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Create manga info from directory structure if not found
    private func createMangaInfoFromDirectory(directory: URL) -> AnyPublisher<Manga, Error> {
        do {
            let mangaId = directory.lastPathComponent
            var title = mangaId.replacingOccurrences(of: "_", with: " ")
            
            // Look for cover image
            var coverImageURL: URL?
            let coverFiles = ["cover.jpg", "cover.png", "cover.jpeg", "thumb.jpg", "thumb.png"]
            
            for coverFile in coverFiles {
                let coverPath = directory.appendingPathComponent(coverFile)
                if fileManager.fileExists(atPath: coverPath.path) {
                    coverImageURL = coverPath
                    break
                }
            }
            
            // Get chapters
            let chapterDirs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath && $0.lastPathComponent != "info" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            
            var chapters: [Chapter] = []
            
            for (index, chapterDir) in chapterDirs.enumerated() {
                let chapterId = chapterDir.lastPathComponent
                let chapterNumber = Double(index + 1)
                
                // Get chapter title
                var chapterTitle: String?
                let titlePath = chapterDir.appendingPathComponent("title.txt")
                if fileManager.fileExists(atPath: titlePath.path) {
                    chapterTitle = try String(contentsOf: titlePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Count pages
                let pages = try fileManager.contentsOfDirectory(at: chapterDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension.lowercased() == "jpg" || 
                              $0.pathExtension.lowercased() == "png" ||
                              $0.pathExtension.lowercased() == "jpeg" }
                
                let chapter = Chapter(
                    id: chapterId,
                    mangaId: mangaId,
                    number: chapterNumber,
                    title: chapterTitle ?? "Chapter \(chapterNumber)",
                    dateReleased: Date(),
                    pageCount: pages.count,
                    isRead: false,
                    pageUrls: nil
                )
                
                chapters.append(chapter)
            }
            
            // Create manga object
            let manga = Manga(
                id: mangaId,
                title: title,
                coverImageURL: coverImageURL,
                author: "Unknown", // Can be customized in info.json
                description: "",    // Can be customized in info.json
                genres: [],         // Can be customized in info.json
                status: .ongoing,   // Can be customized in info.json
                chapters: chapters,
                dateAdded: Date()
            )
            
            // Save generated info to file for future use
            let infoPath = directory.appendingPathComponent("info.json")
            let data = try JSONEncoder().encode(manga)
            try data.write(to: infoPath)
            
            return Just(manga)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Local Source Management
    
    /// Add a new manga to local source
    func addManga(title: String, coverImage: UIImage?, mangaId: String? = nil) -> AnyPublisher<Manga, Error> {
        let id = mangaId ?? UUID().uuidString
        let mangaDir = mangaDirectory.appendingPathComponent(id, isDirectory: true)
        
        do {
            // Create directory
            try fileManager.createDirectory(at: mangaDir, withIntermediateDirectories: true, attributes: nil)
            
            // Save cover image if provided
            if let coverImage = coverImage, let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                let coverPath = mangaDir.appendingPathComponent("cover.jpg")
                try imageData.write(to: coverPath)
            }
            
            // Create manga object
            let manga = Manga(
                id: id,
                title: title,
                coverImageURL: mangaDir.appendingPathComponent("cover.jpg"),
                author: "Unknown",
                description: "",
                genres: [],
                status: .ongoing,
                chapters: [],
                dateAdded: Date()
            )
            
            // Save info
            let infoPath = mangaDir.appendingPathComponent("info.json")
            let data = try JSONEncoder().encode(manga)
            try data.write(to: infoPath)
            
            return Just(manga)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Update manga info (metadata)
    func updateMangaInfo(manga: Manga) -> AnyPublisher<Manga, Error> {
        let mangaPath = mangaDirectory.appendingPathComponent("\(manga.id)/info.json")
        
        do {
            let data = try JSONEncoder().encode(manga)
            try data.write(to: mangaPath)
            return Just(manga).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Add a chapter to a manga
    func addChapter(mangaId: String, chapterNumber: Double, title: String?, images: [UIImage]) -> AnyPublisher<Chapter, Error> {
        let mangaDir = mangaDirectory.appendingPathComponent(mangaId, isDirectory: true)
        let chapterId = "chapter_\(Int(chapterNumber * 100))" // e.g., chapter_100 for chapter 1.0
        let chapterDir = mangaDir.appendingPathComponent(chapterId, isDirectory: true)
        
        do {
            // Create chapter directory
            try fileManager.createDirectory(at: chapterDir, withIntermediateDirectories: true, attributes: nil)
            
            // Save title if provided
            if let title = title {
                let titlePath = chapterDir.appendingPathComponent("title.txt")
                try title.write(to: titlePath, atomically: true, encoding: .utf8)
            }
            
            // Save images
            for (index, image) in images.enumerated() {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let pagePath = chapterDir.appendingPathComponent("page\(String(format: "%03d", index + 1)).jpg")
                    try imageData.write(to: pagePath)
                }
            }
            
            // Create chapter object
            let chapter = Chapter(
                id: chapterId,
                mangaId: mangaId,
                number: chapterNumber,
                title: title,
                dateReleased: Date(),
                pageCount: images.count,
                isRead: false,
                pageUrls: nil
            )
            
            // Update manga info
            return getLocalManga(id: mangaId)
                .flatMap { manga -> AnyPublisher<Manga, Error> in
                    var updatedManga = manga
                    updatedManga.chapters.append(chapter)
                    
                    // Sort chapters by number
                    updatedManga.chapters.sort { $0.number < $1.number }
                    
                    return self.updateMangaInfo(manga: updatedManga)
                }
                .map { _ in chapter }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

// Model for storing reading progress
private struct ReadingProgress: Codable {
    let mangaId: String
    let chapterId: String
    var page: Int
    var dateAccessed: Date
    var isCompleted: Bool
}
