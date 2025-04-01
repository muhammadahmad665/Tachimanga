import SwiftUI

struct MangaGridItem: View {
    let manga: Manga
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                // Cover image
                if let url = manga.coverImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .foregroundColor(.gray)
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(2/3, contentMode: .fit)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .foregroundColor(.gray)
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(Image(systemName: "book.closed"))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .foregroundColor(.gray)
                        .aspectRatio(2/3, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(Image(systemName: "book.closed"))
                }
                
                // Remove button for favorites view
                if showRemoveButton {
                    Button(action: {
                        if let onRemove = onRemove {
                            onRemove()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
            }
            
            Text(manga.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(manga.author)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Reading progress if available
            if let _ = manga.lastReadChapter {
                ProgressView(value: getReadingProgress(manga: manga))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 3)
            }
        }
    }
    
    // Calculate reading progress percentage
    private func getReadingProgress(manga: Manga) -> Float {
        guard !manga.chapters.isEmpty else { return 0 }
        
        let readChapters = manga.chapters.filter { $0.isRead }.count
        return Float(readChapters) / Float(manga.chapters.count)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .padding()
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry") {
                retryAction()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

struct MangaRowView: View {
    let manga: Manga
    
    var body: some View {
        HStack {
            if let url = manga.coverImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "book.closed")
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 60, height: 90)
                .cornerRadius(6)
            } else {
                Image(systemName: "book.closed")
                    .frame(width: 60, height: 90)
            }
            
            VStack(alignment: .leading) {
                Text(manga.title)
                    .font(.headline)
                Text(manga.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    ForEach(manga.genres.prefix(3), id: \.self) { genre in
                        Text(genre)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
