import SwiftUI

struct MangaListView: View {
    @StateObject private var viewModel = MangaListViewModel()
    @State private var isShowingSearchView = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search manga", text: $viewModel.searchQuery)
                        .foregroundColor(.primary)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Search Results
                if !viewModel.searchQuery.isEmpty {
                    if viewModel.searchResults.isEmpty {
                        VStack {
                            Text("No results found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    } else {
                        MangaGridView(title: "Search Results", manga: viewModel.searchResults)
                    }
                } else {
                    // Library content when not searching
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            viewModel.loadData()
                        }
                    } else {
                        // Recently Read Section
                        if !viewModel.recentlyReadManga.isEmpty {
                            MangaRowScrollView(title: "Continue Reading", manga: viewModel.recentlyReadManga, showBadges: true)
                                .padding(.top, 8)
                        }
                        
                        // Favorites Section
                        if !viewModel.favoriteManga.isEmpty {
                            MangaRowScrollView(title: "My Library", manga: viewModel.favoriteManga)
                        }
                        
                        // Popular Manga
                        MangaGridView(title: "Popular Manga", manga: viewModel.popularManga)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Manga")
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.loadData()
        }
    }
}

struct MangaRowScrollView: View {
    let title: String
    let manga: [Manga]
    var showBadges: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if manga.count > 5 {
                    NavigationLink(destination: ViewAllMangaView(title: title, manga: manga)) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 15) {
                    ForEach(manga) { item in
                        NavigationLink(destination: MangaDetailView(mangaId: item.id)) {
                            VStack(alignment: .leading) {
                                ZStack(alignment: .bottomTrailing) {
                                    // Cover image
                                    if let url = item.coverImageURL {
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
                                                    .frame(width: 120, height: 180)
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
                                        .frame(width: 120, height: 180)
                                        .cornerRadius(8)
                                    } else {
                                        Rectangle()
                                            .foregroundColor(.gray)
                                            .frame(width: 120, height: 180)
                                            .cornerRadius(8)
                                            .overlay(Image(systemName: "book.closed"))
                                    }
                                    
                                    // Continue Reading Badge
                                    if showBadges && item.lastReadChapter != nil {
                                        Text("Continue")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                            .padding(8)
                                    }
                                }
                                
                                Text(item.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .frame(width: 120, alignment: .leading)
                                
                                if showBadges && item.lastReadChapter != nil,
                                   let chapter = item.chapters.first(where: { $0.id == item.lastReadChapter }) {
                                    Text("Ch. \(String(format: "%.1f", chapter.number))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 120, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ViewAllMangaView: View {
    let title: String
    let manga: [Manga]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(manga) { item in
                    NavigationLink(destination: MangaDetailView(mangaId: item.id)) {
                        MangaGridItem(manga: item)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(title)
    }
}

struct MangaGridView: View {
    let title: String
    let manga: [Manga]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(manga) { item in
                    NavigationLink(destination: MangaDetailView(mangaId: item.id)) {
                        MangaGridItem(manga: item)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationView {
        MangaListView()
    }
}
