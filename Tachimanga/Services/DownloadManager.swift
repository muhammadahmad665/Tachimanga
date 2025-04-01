import Foundation
import Combine

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeDownloads: [String: DownloadTask] = [:]
    @Published var completedDownloads: [String: DownloadTask] = [:]
    @Published var failedDownloads: [String: (DownloadTask, Error)] = [:]
    
    private let fileManager: FileManager
    private let downloadsURL: URL
    var cancellables = Set<AnyCancellable>()
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // Create downloads directory in Documents
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsURL = documentsURL.appendingPathComponent("Downloads", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        } catch {
            print("Error creating downloads directory: \(error.localizedDescription)")
        }
        
        // Load existing downloads
        loadExistingDownloads()
    }
    
    // MARK: - Public Methods
    
    func downloadChapter(manga: Manga, chapter: Chapter, urls: [URL]) {
        let taskID = "\(manga.id)_\(chapter.id)"
        
        // Check if already downloaded
        if completedDownloads[taskID] != nil {
            print("Chapter already downloaded")
            return
        }
        
        // Check if download is in progress
        if activeDownloads[taskID] != nil {
            print("Download already in progress")
            return
        }
        
        // Create chapter directory
        let chapterDirectory = getChapterDirectory(mangaID: manga.id, chapterID: chapter.id)
        do {
            try fileManager.createDirectory(at: chapterDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating chapter directory: \(error.localizedDescription)")
            return
        }
        
        // Create metadata file
        let metadata = ChapterMetadata(
            mangaID: manga.id,
            mangaTitle: manga.title,
            chapterID: chapter.id,
            chapterNumber: chapter.number,
            chapterTitle: chapter.title,
            pageCount: urls.count,
            downloadDate: Date()
        )
        
        saveMetadata(metadata, to: chapterDirectory)
        
        // Create download task
        let task = DownloadTask(
            id: taskID,
            mangaID: manga.id, 
            chapterID: chapter.id,
            urls: urls,
            progress: 0,
            status: .queued,
            totalPages: urls.count,
            downloadedPages: 0
        )
        
        activeDownloads[taskID] = task
        startDownload(task: task, chapterDirectory: chapterDirectory)
    }
    
    func pauseDownload(mangaID: String, chapterID: String) {
        let taskID = "\(mangaID)_\(chapterID)"
        guard var task = activeDownloads[taskID], task.status == .downloading else {
            return
        }
        
        task.status = .paused
        activeDownloads[taskID] = task
        task.downloadTask?.cancel()
    }
    
    func resumeDownload(mangaID: String, chapterID: String) {
        let taskID = "\(mangaID)_\(chapterID)"
        guard var task = activeDownloads[taskID], task.status == .paused else {
            return
        }
        
        task.status = .queued
        activeDownloads[taskID] = task
        
        let chapterDirectory = getChapterDirectory(mangaID: mangaID, chapterID: chapterID)
        startDownload(task: task, chapterDirectory: chapterDirectory)
    }
    
    func cancelDownload(mangaID: String, chapterID: String) {
        let taskID = "\(mangaID)_\(chapterID)"
        guard let task = activeDownloads[taskID] else {
            return
        }
        
        task.downloadTask?.cancel()
        activeDownloads.removeValue(forKey: taskID)
        
        // Delete partially downloaded files
        let chapterDirectory = getChapterDirectory(mangaID: mangaID, chapterID: chapterID)
        try? fileManager.removeItem(at: chapterDirectory)
    }
    
    func deleteDownload(mangaID: String, chapterID: String) {
        let taskID = "\(mangaID)_\(chapterID)"
        
        // If active, cancel first
        if activeDownloads[taskID] != nil {
            cancelDownload(mangaID: mangaID, chapterID: chapterID)
        }
        
        // Remove from completed
        completedDownloads.removeValue(forKey: taskID)
        
        // Delete directory
        let chapterDirectory = getChapterDirectory(mangaID: mangaID, chapterID: chapterID)
        try? fileManager.removeItem(at: chapterDirectory)
    }
    
    func isDownloaded(mangaID: String, chapterID: String) -> Bool {
        let taskID = "\(mangaID)_\(chapterID)"
        return completedDownloads[taskID] != nil
    }
    
    func getDownloadedChapterUrls(mangaID: String, chapterID: String) -> [URL]? {
        let chapterDirectory = getChapterDirectory(mangaID: mangaID, chapterID: chapterID)
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: chapterDirectory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasSuffix(".jpg") || $0.lastPathComponent.hasSuffix(".png") }
                .sorted { 
                    let page1 = Int($0.lastPathComponent.components(separatedBy: ".").first ?? "0") ?? 0
                    let page2 = Int($1.lastPathComponent.components(separatedBy: ".").first ?? "0") ?? 0
                    return page1 < page2
                }
            
            return fileURLs.isEmpty ? nil : fileURLs
        } catch {
            print("Error getting downloaded chapter: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getDownloadedChapters(for mangaID: String) -> [DownloadedChapter] {
        let mangaDirURL = downloadsURL.appendingPathComponent(mangaID, isDirectory: true)
        
        guard fileManager.fileExists(atPath: mangaDirURL.path) else {
            return []
        }
        
        do {
            let chapterDirs = try fileManager.contentsOfDirectory(at: mangaDirURL, includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath }
            
            return chapterDirs.compactMap { dir -> DownloadedChapter? in
                let metadataURL = dir.appendingPathComponent("metadata.json")
                guard let data = try? Data(contentsOf: metadataURL),
                      let metadata = try? JSONDecoder().decode(ChapterMetadata.self, from: data) else {
                    return nil
                }
                
                return DownloadedChapter(
                    mangaID: metadata.mangaID,
                    mangaTitle: metadata.mangaTitle,
                    chapterID: metadata.chapterID,
                    chapterNumber: metadata.chapterNumber,
                    chapterTitle: metadata.chapterTitle,
                    pageCount: metadata.pageCount,
                    downloadDate: metadata.downloadDate
                )
            }
        } catch {
            print("Error loading downloaded chapters: \(error.localizedDescription)")
            return []
        }
    }
    
    func getDownloadedManga() -> [DownloadedManga] {
        do {
            let mangaDirs = try fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath }
            
            return mangaDirs.compactMap { dir -> DownloadedManga? in
                let mangaID = dir.lastPathComponent
                let chapters = getDownloadedChapters(for: mangaID)
                
                guard !chapters.isEmpty, let firstChapter = chapters.first else {
                    return nil
                }
                
                return DownloadedManga(
                    id: mangaID,
                    title: firstChapter.mangaTitle,
                    chapters: chapters,
                    coverImageURL: getCoverImageURL(mangaID: mangaID)
                )
            }
        } catch {
            print("Error loading downloaded manga: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func saveMetadata(_ metadata: ChapterMetadata, to directory: URL) {
        do {
            let data = try JSONEncoder().encode(metadata)
            let fileURL = directory.appendingPathComponent("metadata.json")
            try data.write(to: fileURL)
        } catch {
            print("Error saving metadata: \(error.localizedDescription)")
        }
    }
    
    private func startDownload(task: DownloadTask, chapterDirectory: URL) {
        var currentTask = task
        currentTask.status = .downloading
        activeDownloads[task.id] = currentTask
        
        downloadImages(task: currentTask, chapterDirectory: chapterDirectory)
    }
    
    private func downloadImages(task: DownloadTask, chapterDirectory: URL) {
        guard task.downloadedPages < task.urls.count else {
            completeDownload(task: task)
            return
        }
        
        var currentTask = task
        let pageIndex = task.downloadedPages
        let url = task.urls[pageIndex]
        let filename = "\(pageIndex + 1).\(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)"
        let destination = chapterDirectory.appendingPathComponent(filename)
        
        // Check if file already exists (for resuming)
        if fileManager.fileExists(atPath: destination.path) {
            currentTask.downloadedPages += 1
            currentTask.progress = Float(currentTask.downloadedPages) / Float(currentTask.totalPages)
            activeDownloads[task.id] = currentTask
            
            // Download next page
            downloadImages(task: currentTask, chapterDirectory: chapterDirectory)
            return
        }
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                self?.handleDownloadError(taskID: task.id, error: error ?? NSError(domain: "DownloadManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown download error"]))
                return
            }
            
            do {
                try self.fileManager.moveItem(at: tempURL, to: destination)
                
                DispatchQueue.main.async {
                    var updatedTask = self.activeDownloads[task.id]!
                    updatedTask.downloadedPages += 1
                    updatedTask.progress = Float(updatedTask.downloadedPages) / Float(updatedTask.totalPages)
                    self.activeDownloads[task.id] = updatedTask
                    
                    // Download next page
                    if updatedTask.status == .downloading {
                        self.downloadImages(task: updatedTask, chapterDirectory: chapterDirectory)
                    }
                }
            } catch {
                self.handleDownloadError(taskID: task.id, error: error)
            }
        }
        
        currentTask.downloadTask = downloadTask
        activeDownloads[task.id] = currentTask
        downloadTask.resume()
    }
    
    private func completeDownload(task: DownloadTask) {
        var completedTask = task
        completedTask.status = .completed
        completedTask.progress = 1.0
        
        activeDownloads.removeValue(forKey: task.id)
        completedDownloads[task.id] = completedTask
        
        // Save cover image if it doesn't exist
        if let manga = ServiceProvider.shared.mangaRepository as? MockMangaRepository {
            if let mangaData = manga.mangaDatabase.first(where: { $0.id == task.mangaID }),
               let coverURL = mangaData.coverImageURL {
                downloadCoverImage(mangaID: task.mangaID, url: coverURL)
            }
        }
        
        NotificationCenter.default.post(name: .chapterDownloadCompleted, object: nil, userInfo: ["taskID": task.id])
    }
    
    private func handleDownloadError(taskID: String, error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, var task = self.activeDownloads[taskID] else { return }
            
            if (error as NSError).code == NSURLErrorCancelled {
                // This is a cancel operation, not an error
                if task.status != .paused {
                    self.activeDownloads.removeValue(forKey: taskID)
                }
            } else {
                task.status = .failed
                self.activeDownloads.removeValue(forKey: taskID)
                self.failedDownloads[taskID] = (task, error)
            }
        }
    }
    
    private func downloadCoverImage(mangaID: String, url: URL) {
        let mangaDirectory = getMangaDirectory(mangaID: mangaID)
        let coverURL = mangaDirectory.appendingPathComponent("cover.jpg")
        
        // Skip if cover already exists
        if fileManager.fileExists(atPath: coverURL.path) {
            return
        }
        
        // Create manga directory if needed
        do {
            try fileManager.createDirectory(at: mangaDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating manga directory: \(error)")
            return
        }
        
        // Download cover
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Error downloading cover: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                try data.write(to: coverURL)
            } catch {
                print("Error saving cover: \(error)")
            }
        }.resume()
    }
    
    private func loadExistingDownloads() {
        let downloadedManga = getDownloadedManga()
        
        for manga in downloadedManga {
            for chapter in manga.chapters {
                let taskID = "\(chapter.mangaID)_\(chapter.chapterID)"
                let task = DownloadTask(
                    id: taskID,
                    mangaID: chapter.mangaID,
                    chapterID: chapter.chapterID,
                    urls: [],
                    progress: 1.0,
                    status: .completed,
                    totalPages: chapter.pageCount,
                    downloadedPages: chapter.pageCount
                )
                completedDownloads[taskID] = task
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMangaDirectory(mangaID: String) -> URL {
        return downloadsURL.appendingPathComponent(mangaID, isDirectory: true)
    }
    
    private func getChapterDirectory(mangaID: String, chapterID: String) -> URL {
        return getMangaDirectory(mangaID: mangaID).appendingPathComponent(chapterID, isDirectory: true)
    }
    
    private func getCoverImageURL(mangaID: String) -> URL? {
        let coverURL = getMangaDirectory(mangaID: mangaID).appendingPathComponent("cover.jpg")
        return fileManager.fileExists(atPath: coverURL.path) ? coverURL : nil
    }
}

// MARK: - Models

struct DownloadTask {
    let id: String // mangaID_chapterID
    let mangaID: String
    let chapterID: String
    let urls: [URL]
    var progress: Float
    var status: DownloadStatus
    let totalPages: Int
    var downloadedPages: Int
    var downloadTask: URLSessionDownloadTask?
}

enum DownloadStatus {
    case queued
    case downloading
    case paused
    case completed
    case failed
}

struct ChapterMetadata: Codable {
    let mangaID: String
    let mangaTitle: String
    let chapterID: String
    let chapterNumber: Double
    let chapterTitle: String?
    let pageCount: Int
    let downloadDate: Date
}

struct DownloadedChapter {
    let mangaID: String
    let mangaTitle: String
    let chapterID: String
    let chapterNumber: Double
    let chapterTitle: String?
    let pageCount: Int
    let downloadDate: Date
}

struct DownloadedManga {
    let id: String
    let title: String
    let chapters: [DownloadedChapter]
    let coverImageURL: URL?
}

extension Notification.Name {
    static let chapterDownloadCompleted = Notification.Name("chapterDownloadCompleted")
}
