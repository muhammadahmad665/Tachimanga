import Foundation
import Combine
import UIKit

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadedItems: [String: [String]] = [:] // [mangaId: [chapterId]]
    @Published var activeDownloads: Set<String> = [] // [mangaId_chapterId]
    
    var cancellables = Set<AnyCancellable>()
    
    private let documentsDirectory: URL
    private let downloadsDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectory = documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        
        // Create downloads directory if it doesn't exist
        try? FileManager.default.createDirectory(at: downloadsDirectory, 
                                                withIntermediateDirectories: true)
        
        // Load existing downloads
        loadDownloadedItems()
    }
    
    func downloadChapter(manga: Manga, chapter: Chapter, urls: [URL]) {
        let mangaId = manga.id
        let chapterId = chapter.id
        let combinedId = "\(mangaId)_\(chapterId)"
        
        // Don't download if already downloaded or in progress
        guard !isDownloaded(mangaID: mangaId, chapterID: chapterId) && !activeDownloads.contains(combinedId) else {
            return
        }
        
        // Mark as downloading
        activeDownloads.insert(combinedId)
        
        // Create chapter directory
        let mangaDirectory = downloadsDirectory.appendingPathComponent(mangaId, isDirectory: true)
        let chapterDirectory = mangaDirectory.appendingPathComponent(chapterId, isDirectory: true)
        
        try? FileManager.default.createDirectory(at: chapterDirectory, 
                                               withIntermediateDirectories: true)
        
        // Save info.json for the manga
        let mangaInfoPath = mangaDirectory.appendingPathComponent("info.json")
        try? JSONEncoder().encode(manga).write(to: mangaInfoPath)
        
        // Download all images
        var downloadedCount = 0
        let totalCount = urls.count
        
        for (index, url) in urls.enumerated() {
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure = completion {
                            downloadedCount += 1
                            // Check if all downloads completed
                            if downloadedCount == totalCount {
                                self?.finishDownload(mangaId: mangaId, chapterId: chapterId)
                            }
                        }
                    },
                    receiveValue: { [weak self] data in
                        let imagePath = chapterDirectory.appendingPathComponent("page\(index+1).jpg")
                        try? data.write(to: imagePath)
                        
                        downloadedCount += 1
                        
                        // Check if all downloads completed
                        if downloadedCount == totalCount {
                            self?.finishDownload(mangaId: mangaId, chapterId: chapterId)
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func finishDownload(mangaId: String, chapterId: String) {
        let combinedId = "\(mangaId)_\(chapterId)"
        
        // Remove from active downloads
        activeDownloads.remove(combinedId)
        
        // Add to downloaded items
        if downloadedItems[mangaId] != nil {
            if !downloadedItems[mangaId]!.contains(chapterId) {
                downloadedItems[mangaId]!.append(chapterId)
            }
        } else {
            downloadedItems[mangaId] = [chapterId]
        }
        
        // Save updated download list
        saveDownloadedItems()
    }
    
    func deleteDownload(mangaID: String, chapterID: String) {
        let chapterDir = downloadsDirectory
            .appendingPathComponent(mangaID, isDirectory: true)
            .appendingPathComponent(chapterID, isDirectory: true)
        
        // Try to delete the directory
        try? FileManager.default.removeItem(at: chapterDir)
        
        // Update the downloaded items list
        if var chapters = downloadedItems[mangaID] {
            chapters.removeAll { $0 == chapterID }
            
            if chapters.isEmpty {
                downloadedItems.removeValue(forKey: mangaID)
            } else {
                downloadedItems[mangaID] = chapters
            }
            
            saveDownloadedItems()
        }
    }
    
    func isDownloaded(mangaID: String, chapterID: String) -> Bool {
        if let chapters = downloadedItems[mangaID] {
            return chapters.contains(chapterID)
        }
        return false
    }
    
    func getDownloadedChapterUrls(mangaID: String, chapterID: String) -> [URL]? {
        guard isDownloaded(mangaID: mangaID, chapterID: chapterID) else { return nil }
        
        let chapterDir = downloadsDirectory
            .appendingPathComponent(mangaID, isDirectory: true)
            .appendingPathComponent(chapterID, isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: chapterDir.path) else { return nil }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: chapterDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "jpg" || 
                          $0.pathExtension.lowercased() == "png" ||
                          $0.pathExtension.lowercased() == "jpeg" }
                .sorted { 
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
            
            return fileURLs
        } catch {
            print("Error getting chapter URLs: \(error)")
            return nil
        }
    }
    
    private func saveDownloadedItems() {
        let downloadListPath = documentsDirectory.appendingPathComponent("downloadList.json")
        try? JSONEncoder().encode(downloadedItems).write(to: downloadListPath)
    }
    
    private func loadDownloadedItems() {
        let downloadListPath = documentsDirectory.appendingPathComponent("downloadList.json")
        
        if FileManager.default.fileExists(atPath: downloadListPath.path),
           let data = try? Data(contentsOf: downloadListPath),
           let downloads = try? JSONDecoder().decode([String: [String]].self, from: data) {
            downloadedItems = downloads
        }
        
        // Verify downloaded items still exist
        validateDownloads()
    }
    
    private func validateDownloads() {
        for (mangaId, chapterIds) in downloadedItems {
            let mangaDir = downloadsDirectory.appendingPathComponent(mangaId, isDirectory: true)
            
            if !FileManager.default.fileExists(atPath: mangaDir.path) {
                downloadedItems.removeValue(forKey: mangaId)
                continue
            }
            
            var validChapterIds = [String]()
            
            for chapterId in chapterIds {
                let chapterDir = mangaDir.appendingPathComponent(chapterId, isDirectory: true)
                if FileManager.default.fileExists(atPath: chapterDir.path) {
                    validChapterIds.append(chapterId)
                }
            }
            
            if validChapterIds.isEmpty {
                downloadedItems.removeValue(forKey: mangaId)
            } else {
                downloadedItems[mangaId] = validChapterIds
            }
        }
        
        saveDownloadedItems()
    }
    
    // MARK: - Offline Library Support
    
    /// Get all downloaded manga for the offline library
    func getDownloadedManga() -> [DownloadedManga] {
        var result = [DownloadedManga]()
        
        for (mangaId, chapters) in downloadedItems {
            // Try to load manga info
            let mangaInfoPath = downloadsDirectory.appendingPathComponent("\(mangaId)/info.json")
            
            var title = "Unknown Manga"
            var coverImageURL: URL? = nil
            
            if FileManager.default.fileExists(atPath: mangaInfoPath.path),
               let data = try? Data(contentsOf: mangaInfoPath),
               let manga = try? JSONDecoder().decode(Manga.self, from: data) {
                title = manga.title
                coverImageURL = manga.coverImageURL
            }
            
            // Create downloaded chapters
            var downloadedChapters = [DownloadedChapter]()
            
            for chapterId in chapters {
                // Get chapter info if available
                var chapterTitle: String? = nil
                var chapterNumber = 1.0
                
                // Try to parse chapter number from ID (e.g., "chapter_100" -> 1.0)
                if chapterId.hasPrefix("chapter_") {
                    let numberStr = chapterId.replacingOccurrences(of: "chapter_", with: "")
                    if let num = Double(numberStr) {
                        chapterNumber = num / 100.0 // Convert back from integer format
                    }
                }
                
                // Get title.txt if it exists
                let titlePath = downloadsDirectory
                    .appendingPathComponent("\(mangaId)/\(chapterId)/title.txt")
                if FileManager.default.fileExists(atPath: titlePath.path) {
                    chapterTitle = try? String(contentsOf: titlePath, encoding: .utf8)
                }
                
                let chapter = DownloadedChapter(
                    mangaID: mangaId,
                    chapterID: chapterId,
                    chapterNumber: chapterNumber,
                    chapterTitle: chapterTitle,
                    downloadDate: Date() // In a real implementation, store and retrieve this
                )
                
                downloadedChapters.append(chapter)
            }
            
            let downloadedManga = DownloadedManga(
                id: mangaId,
                title: title,
                coverImageURL: coverImageURL,
                chapters: downloadedChapters
            )
            
            result.append(downloadedManga)
        }
        
        return result.sorted { $0.title < $1.title }
    }
}

// MARK: - Models for downloaded manga

struct DownloadedManga: Identifiable {
    let id: String
    let title: String
    let coverImageURL: URL?
    let chapters: [DownloadedChapter]
}

struct DownloadedChapter: Identifiable {
    var id: String { chapterID }
    let mangaID: String
    let chapterID: String
    let chapterNumber: Double
    let chapterTitle: String?
    let downloadDate: Date
}
