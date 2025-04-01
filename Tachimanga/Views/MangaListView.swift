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
                    // Popular Manga
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            viewModel.loadPopularManga()
                        }
                    } else {
                        if (!viewModel.favoriteManga.isEmpty) {
                            MangaRowScrollView(title: "My Library", manga: viewModel.favoriteManga)
                        }
                        
                        MangaGridView(title: "Popular Manga", manga: viewModel.popularManga)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Manga")
        .onAppear {
            viewModel.loadPopularManga()
            viewModel.loadFavorites()
        }
    }
}

struct MangaRowScrollView: View {
    let title: String
    let manga: [Manga]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 15) {
                    ForEach(manga) { item in
                        NavigationLink(destination: MangaDetailView(mangaId: item.id)) {
                            VStack(alignment: .leading) {
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
                                
                                Text(item.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
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

struct MangaGridItem: View {
    let manga: Manga
    
    var body: some View {
        VStack(alignment: .leading) {
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
            
            Text(manga.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(manga.author)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
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

#Preview {
    NavigationView {
        MangaListView()
    }
}
