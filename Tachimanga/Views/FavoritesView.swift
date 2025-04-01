import SwiftUI
import Combine

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.favorites.isEmpty {
                emptyFavoritesView
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(viewModel.favorites) { manga in
                            NavigationLink(destination: MangaDetailView(mangaId: manga.id)) {
                                MangaGridItem(manga: manga, showRemoveButton: true) {
                                    viewModel.removeFavorite(mangaId: manga.id)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favorites")
        .onAppear {
            viewModel.loadFavorites()
        }
        .refreshable {
            viewModel.loadFavorites()
        }
    }
    
    private var emptyFavoritesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add manga to your favorites to quickly access them later")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

class FavoritesViewModel: ObservableObject {
    @Published var favorites: [Manga] = []
    @Published var isLoading = false
    
    private let repository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MangaRepository = MockMangaRepository()) {
        self.repository = repository
    }
    
    func loadFavorites() {
        isLoading = true
        
        repository.getFavorites()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] favorites in
                    self?.favorites = favorites
                }
            )
            .store(in: &cancellables)
    }
    
    func removeFavorite(mangaId: String) {
        repository.toggleFavorite(mangaId: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.favorites.removeAll { $0.id == mangaId }
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    NavigationView {
        FavoritesView()
    }
}
