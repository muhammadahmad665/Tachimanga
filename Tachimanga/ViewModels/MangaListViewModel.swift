import Foundation
import Combine

class MangaListViewModel: ObservableObject {
    @Published var popularManga: [Manga] = []
    @Published var favoriteManga: [Manga] = []
    @Published var recentlyReadManga: [Manga] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchResults: [Manga] = []
    @Published var searchQuery: String = ""
    
    private let repository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MangaRepository = MockMangaRepository()) {
        self.repository = repository
        
        // Setup search functionality
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                self?.searchManga(query: query)
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        loadPopularManga()
        loadFavorites()
        loadRecentlyRead()
    }
    
    func loadPopularManga() {
        isLoading = true
        errorMessage = nil
        
        repository.fetchPopularManga()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] manga in
                    self?.popularManga = manga
                }
            )
            .store(in: &cancellables)
    }
    
    func loadFavorites() {
        repository.getFavorites()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] favorites in
                    self?.favoriteManga = favorites
                }
            )
            .store(in: &cancellables)
    }
    
    func loadRecentlyRead() {
        repository.getRecentlyReadManga(limit: 10)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] manga in
                    self?.recentlyReadManga = manga
                }
            )
            .store(in: &cancellables)
    }
    
    func searchManga(query: String) {
        repository.searchManga(query: query)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] results in
                    self?.searchResults = results
                }
            )
            .store(in: &cancellables)
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
}
