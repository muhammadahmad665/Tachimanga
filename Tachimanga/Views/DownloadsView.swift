import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showDeleteConfirmation = false
    @State private var mangaToDelete: String? = nil
    
    private var activeDownloads: [DownloadTask] {
        Array(downloadManager.activeDownloads.values)
    }
    
    private var completedDownloads: [DownloadTask] {
        Array(downloadManager.completedDownloads.values)
            .sorted(by: { $0.id < $1.id })
    }
    
    private var failedDownloads: [(DownloadTask, Error)] {
        Array(downloadManager.failedDownloads.values)
    }
    
    private var hasActiveDownloads: Bool {
        !activeDownloads.isEmpty
    }
    
    var body: some View {
        List {
            if hasActiveDownloads {
                Section(header: Text("Active Downloads")) {
                    ForEach(activeDownloads, id: \.id) { task in
                        DownloadTaskRow(task: task)
                    }
                }
            }
            
            if !failedDownloads.isEmpty {
                Section(header: Text("Failed Downloads")) {
                    ForEach(failedDownloads, id: \.0.id) { (task, error) in
                        FailedDownloadRow(task: task, error: error)
                    }
                }
            }
            
            if !completedDownloads.isEmpty {
                Section(header: Text("Recent Downloads")) {
                    ForEach(completedDownloads.prefix(5), id: \.id) { task in
                        CompletedDownloadRow(task: task)
                    }
                    
                    if completedDownloads.count > 5 {
                        NavigationLink(destination: OfflineLibraryView()) {
                            Text("View All \(completedDownloads.count) Downloads")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            if !hasActiveDownloads && completedDownloads.isEmpty && failedDownloads.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No Downloads")
                            .font(.headline)
                        
                        Text("Download chapters to read offline when you don't have an internet connection.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        NavigationLink(destination: BrowseView()) {
                            Text("Browse Manga")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Downloads")
        .toolbar {
            if hasActiveDownloads {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Cancel all downloads
                        for task in activeDownloads {
                            downloadManager.cancelDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                        }
                    }) {
                        Text("Cancel All")
                    }
                }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Download?"),
                message: Text("This will permanently delete the downloaded chapter. You can download it again later."),
                primaryButton: .destructive(Text("Delete")) {
                    if let mangaID = mangaToDelete {
                        // Split the mangaID which contains both mangaID and chapterID
                        let components = mangaID.components(separatedBy: "_")
                        if components.count == 2 {
                            downloadManager.deleteDownload(mangaID: components[0], chapterID: components[1])
                        }
                        mangaToDelete = nil
                    }
                },
                secondaryButton: .cancel {
                    mangaToDelete = nil
                }
            )
        }
    }
}

struct DownloadTaskRow: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    let task: DownloadTask
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Chapter \(getChapterNumber(task: task))")
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(task.progress * 100))%")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: task.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.vertical, 4)
            
            HStack {
                Text("\(task.downloadedPages)/\(task.totalPages) pages")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                switch task.status {
                case .downloading:
                    Button(action: {
                        downloadManager.pauseDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                    }) {
                        Image(systemName: "pause.circle")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        downloadManager.cancelDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .padding(.leading, 8)
                    
                case .paused:
                    Button(action: {
                        downloadManager.resumeDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                    }) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        downloadManager.cancelDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .padding(.leading, 8)
                    
                case .queued:
                    HStack {
                        Image(systemName: "hourglass")
                        Text("Queued")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                default:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getChapterNumber(task: DownloadTask) -> String {
        // Try to find chapter in the repository
        if let manga = ServiceProvider.shared.mangaRepository as? MockMangaRepository,
           let mangaData = manga.mangaDatabase.first(where: { $0.id == task.mangaID }),
           let chapter = mangaData.chapters.first(where: { $0.id == task.chapterID }) {
            return String(format: "%.1f", chapter.number)
        }
        
        // If not found, use the task ID
        return task.id
    }
}

struct CompletedDownloadRow: View {
    let task: DownloadTask
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Chapter \(getChapterNumber(task: task))")
                    .fontWeight(.medium)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Download?"),
                message: Text("This will permanently delete the downloaded chapter."),
                primaryButton: .destructive(Text("Delete")) {
                    DownloadManager.shared.deleteDownload(mangaID: task.mangaID, chapterID: task.chapterID)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func getChapterNumber(task: DownloadTask) -> String {
        // Try to find chapter in the repository
        if let manga = ServiceProvider.shared.mangaRepository as? MockMangaRepository,
           let mangaData = manga.mangaDatabase.first(where: { $0.id == task.mangaID }),
           let chapter = mangaData.chapters.first(where: { $0.id == task.chapterID }) {
            return String(format: "%.1f", chapter.number)
        }
        
        // If not found, use the task ID
        return task.id
    }
}

struct FailedDownloadRow: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    let task: DownloadTask
    let error: Error
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Chapter \(getChapterNumber(task: task))")
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
            
            Text("Error: \(error.localizedDescription)")
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)
                .padding(.vertical, 4)
            
            HStack {
                Button(action: {
                    // Try again - create a new download task
                    if let manga = ServiceProvider.shared.mangaRepository as? MockMangaRepository,
                       let mangaData = manga.mangaDatabase.first(where: { $0.id == task.mangaID }),
                       let chapter = mangaData.chapters.first(where: { $0.id == task.chapterID }) {
                        
                        // Get the URLs for this chapter
                        ServiceProvider.shared.mangaRepository.fetchChapterPages(mangaId: task.mangaID, chapterId: task.chapterID)
                            .sink(
                                receiveCompletion: { _ in },
                                receiveValue: { urls in
                                    // Clean up the failed download
                                    downloadManager.failedDownloads.removeValue(forKey: task.id)
                                    
                                    // Start a new download
                                    downloadManager.downloadChapter(
                                        manga: mangaData,
                                        chapter: chapter,
                                        urls: urls
                                    )
                                }
                            )
                            .store(in: &downloadManager.cancellables)
                    }
                }) {
                    Text("Try Again")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    // Remove from failed list
                    downloadManager.failedDownloads.removeValue(forKey: task.id)
                }) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getChapterNumber(task: DownloadTask) -> String {
        // Try to find chapter in the repository
        if let manga = ServiceProvider.shared.mangaRepository as? MockMangaRepository,
           let mangaData = manga.mangaDatabase.first(where: { $0.id == task.mangaID }),
           let chapter = mangaData.chapters.first(where: { $0.id == task.chapterID }) {
            return String(format: "%.1f", chapter.number)
        }
        
        // If not found, use the task ID
        return task.id
    }
}

#Preview {
    NavigationView {
        DownloadsView()
    }
}
