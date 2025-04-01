import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var expandedManga: Set<String> = []
    @State private var showDeleteAlert = false
    @State private var mangaToDelete: String? = nil
    @State private var chapterToDelete: String? = nil
    
    var body: some View {
        Group {
            if downloadManager.downloadedItems.isEmpty {
                emptyDownloadsView
            } else {
                downloadsList
            }
        }
        .navigationTitle("Downloads")
    }
    
    private var emptyDownloadsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding()
            
            Text("No Downloaded Manga")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Downloaded chapters will appear here for offline reading")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            NavigationLink(destination: BrowseView()) {
                Text("Browse Manga")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var downloadsList: some View {
        List {
            ForEach(Array(downloadManager.downloadedItems.keys.sorted()), id: \.self) { mangaId in
                MangaDownloadsSection(
                    mangaId: mangaId,
                    isExpanded: expandedManga.contains(mangaId),
                    onToggle: { toggleMangaExpansion(mangaId) },
                    onDeleteChapter: { chapterId in
                        mangaToDelete = mangaId
                        chapterToDelete = chapterId
                        showDeleteAlert = true
                    }
                )
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Download"),
                message: Text("Are you sure you want to delete this downloaded chapter? It will no longer be available offline."),
                primaryButton: .destructive(Text("Delete")) {
                    if let mangaId = mangaToDelete, let chapterId = chapterToDelete {
                        downloadManager.deleteDownload(mangaID: mangaId, chapterID: chapterId)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func toggleMangaExpansion(_ mangaId: String) {
        if expandedManga.contains(mangaId) {
            expandedManga.remove(mangaId)
        } else {
            expandedManga.insert(mangaId)
        }
    }
}

struct MangaDownloadsSection: View {
    let mangaId: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDeleteChapter: (String) -> Void
    
    @State private var manga: Manga?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Manga header
            Button(action: onToggle) {
                HStack {
                    if let manga = manga {
                        AsyncImage(url: manga.coverImageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 70)
                                    .cornerRadius(4)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 70)
                                    .cornerRadius(4)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(manga.title)
                                .font(.headline)
                            
                            if let chapters = DownloadManager.shared.downloadedItems[mangaId] {
                                Text("\(chapters.count) downloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if isLoading {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 70)
                            .cornerRadius(4)
                        
                        ProgressView()
                            .padding(.horizontal)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 70)
                            .cornerRadius(4)
                        
                        Text("Unknown Manga")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Chapter list (if expanded)
            if isExpanded, let chapters = DownloadManager.shared.downloadedItems[mangaId], !chapters.isEmpty {
                ForEach(chapters.sorted(), id: \.self) { chapterId in
                    ChapterDownloadRow(
                        mangaId: mangaId,
                        chapterId: chapterId,
                        manga: manga,
                        onDelete: { onDeleteChapter(chapterId) }
                    )
                }
                .padding(.leading)
            }
        }
        .onAppear {
            loadMangaDetails()
        }
    }
    
    private func loadMangaDetails() {
        isLoading = true
        
        ServiceProvider.shared.mangaRepository.fetchMangaDetails(id: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    isLoading = false
                },
                receiveValue: { loadedManga in
                    manga = loadedManga
                    isLoading = false
                }
            )
            .store(in: &DownloadManager.shared.cancellables)
    }
}

struct ChapterDownloadRow: View {
    let mangaId: String
    let chapterId: String
    let manga: Manga?
    let onDelete: () -> Void
    
    var chapter: Chapter? {
        manga?.chapters.first(where: { $0.id == chapterId })
    }
    
    var body: some View {
        NavigationLink(destination: ChapterReaderView(chapter: chapter ?? createTemporaryChapter())) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let chapter = chapter {
                        Text("Chapter \(String(format: "%.1f", chapter.number))")
                            .fontWeight(.medium)
                        
                        if let title = chapter.title {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(chapterId.replacingOccurrences(of: "_", with: " ").capitalized)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    // Create a temporary chapter object when the real chapter data isn't available
    private func createTemporaryChapter() -> Chapter {
        return Chapter(
            id: chapterId,
            mangaId: mangaId,
            number: 0,
            title: "Unknown Chapter",
            dateReleased: Date(),
            pageCount: 0,
            isRead: false,
            pageUrls: nil
        )
    }
}

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DownloadsView()
        }
    }
}
