import SwiftUI

struct MangaDetailView: View {
    let mangaId: String
    @StateObject private var viewModel = MangaDetailViewModel()
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.red)
                    Button("Retry") {
                        viewModel.loadMangaDetails(id: mangaId)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else if let manga = viewModel.manga {
                VStack(alignment: .leading) {
                    // Cover and basic info
                    ZStack(alignment: .bottom) {
                        // Background header image
                        if let url = manga.coverImageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 200)
                                        .blur(radius: 8)
                                        .clipped()
                                        .overlay(Color.black.opacity(0.4))
                                default:
                                    Color.gray
                                }
                            }
                        } else {
                            Color.gray
                        }
                        
                        HStack(alignment: .bottom, spacing: 16) {
                            // Cover image
                            if let url = manga.coverImageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .foregroundColor(.gray.opacity(0.3))
                                            .frame(width: 120, height: 180)
                                            .overlay(ProgressView())
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 180)
                                    case .failure:
                                        Rectangle()
                                            .foregroundColor(.gray.opacity(0.3))
                                            .frame(width: 120, height: 180)
                                            .overlay(Image(systemName: "book.closed"))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .cornerRadius(8)
                                .shadow(radius: 4)
                            } else {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 120, height: 180)
                                    .cornerRadius(8)
                                    .overlay(Image(systemName: "book.closed"))
                                    .shadow(radius: 4)
                            }
                            
                            // Title and metadata
                            VStack(alignment: .leading, spacing: 4) {
                                Text(manga.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text("by \(manga.author)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    Text(manga.status.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusColor(manga.status))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.toggleFavorite()
                                    }) {
                                        Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                            .foregroundColor(viewModel.isFavorite ? .red : .white)
                                            .frame(width: 32, height: 32)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.bottom, 16)
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 200)
                    
                    // Continue Reading Button (if applicable)
                    if viewModel.hasReadingProgress, let lastChapter = viewModel.getLastReadChapter() {
                        VStack {
                            NavigationLink(destination: ChapterReaderView(
                                chapter: lastChapter,
                                initialPage: viewModel.lastReadPage
                            )) {
                                HStack {
                                    Image(systemName: "book.circle")
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Continue Reading")
                                            .font(.headline)
                                        
                                        Text("Chapter \(String(format: "%.1f", lastChapter.number))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Genres
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(manga.genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Synopsis")
                            .font(.headline)
                        
                        Text(manga.description)
                            .font(.body)
                            .lineLimit(nil)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Chapter List Header with Reading Progress
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Chapters")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !viewModel.readChapters.isEmpty {
                                Text("\(viewModel.readChapters.count)/\(manga.chapters.count) read")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(manga.chapters.count) chapters")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ForEach(manga.chapters) { chapter in
                            EnhancedChapterRowView(
                                manga: manga,
                                chapter: chapter,
                                isDownloaded: downloadManager.isDownloaded(mangaID: manga.id, chapterID: chapter.id),
                                onMarkRead: { viewModel.markChapterAsRead(chapterId: chapter.id) },
                                onMarkUnread: { viewModel.markChapterAsUnread(chapterId: chapter.id) }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.manga?.title ?? "Manga Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMangaDetails(id: mangaId)
        }
    }
    
    func statusColor(_ status: MangaStatus) -> Color {
        switch status {
        case .ongoing:
            return .green
        case .completed:
            return .blue
        case .hiatus:
            return .orange
        case .cancelled:
            return .red
        }
    }
}

struct EnhancedChapterRowView: View {
    let manga: Manga
    let chapter: Chapter
    let isDownloaded: Bool
    let onMarkRead: () -> Void
    let onMarkUnread: () -> Void
    
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showDownloadingToast = false
    
    var body: some View {
        NavigationLink(destination: ChapterReaderView(chapter: chapter)) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Chapter \(String(format: "%.1f", chapter.number))")
                        .font(.subheadline)
                        .fontWeight(chapter.isRead ? .regular : .bold)
                        .foregroundColor(chapter.isRead ? .secondary : .primary)
                    
                    if let title = chapter.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack {
                    if chapter.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                    
                    Text(formatDate(chapter.dateReleased))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if isDownloaded {
                Button(role: .destructive) {
                    downloadManager.deleteDownload(mangaID: manga.id, chapterID: chapter.id)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            } else {
                Button {
                    downloadChapter()
                } label: {
                    Label("Download Chapter", systemImage: "arrow.down")
                }
            }
            
            if chapter.isRead {
                Button {
                    onMarkUnread()
                } label: {
                    Label("Mark as Unread", systemImage: "book") 
                }
            } else {
                Button {
                    onMarkRead()
                } label: {
                    Label("Mark as Read", systemImage: "checkmark")
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func downloadChapter() {
        // Get chapter pages
        ServiceProvider.shared.mangaRepository.fetchChapterPages(mangaId: manga.id, chapterId: chapter.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { urls in
                    downloadManager.downloadChapter(manga: manga, chapter: chapter, urls: urls)
                    showDownloadingToast = true
                }
            )
            .store(in: &downloadManager.cancellables)
    }
}

//#Preview {
//    NavigationView {
//        MangaDetailView(mangaId: "sample1")
//    }
//}
