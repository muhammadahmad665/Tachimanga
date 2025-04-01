import Foundation
import Combine

class BrowseViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var selectedGenres: [String] = []
    @Published var manga: [Manga] = []
    @Published var searchResults: [Manga] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentPage: Int = 1
    @Published var currentSortOption: SortOption = .popularity
    
    // Add refresh control coordinator - initialize it later to avoid 'self' capture issues
    lazy var refreshControl: RefreshControlCoordinator = {
        return RefreshControlCoordinator(action: { [weak self] in
            self?.refreshData()
        })
    }()
    
    var displayedManga: [Manga] {
        if !searchQuery.isEmpty {
            return searchResults
        } else if !selectedGenres.isEmpty {
            return manga.filter { manga in
                !Set(manga.genres).isDisjoint(with: Set(selectedGenres))
            }
        } else {
            return manga
        }
    }
    
    var activeFilters: [String] {
        var filters: [String] = []
        filters.append(contentsOf: selectedGenres)
        return filters
    }
    
    // Common genre list for manga
    let availableGenres = [
        "Action", "Adventure", "Comedy", "Drama", "Fantasy",
        "Horror", "Mystery", "Romance", "Sci-Fi", "Slice of Life",
        "Sports", "Supernatural", "Thriller", "Historical", "Psychological",
        "Seinen", "Shoujo", "Shounen", "Tragedy", "Isekai",
        "Mecha", "Martial Arts", "School Life", "Harem", "Magic"
    ].sorted()
    
    private let repository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MangaRepository = MockMangaRepository()) {
        self.repository = repository
        
        // No need to initialize refreshControl here anymore since it's now a lazy property
        
        // Setup search functionality
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.searchResults = []
                } else {
                    self?.searchManga(query: query)
                }
            }
            .store(in: &cancellables)
        
        // Setup genre filter functionality
        $selectedGenres
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterByGenres()
            }
            .store(in: &cancellables)
    }
    
    func loadManga() {
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
                    self?.manga = manga
                    self?.sortManga(by: self?.currentSortOption ?? .popularity)
                }
            )
            .store(in: &cancellables)
    }
    
    func loadMoreManga() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        // In a real app, this would fetch the next page from the API
        // For now, we'll just simulate by adding more sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            
            let newManga = Manga.samples
            self.manga.append(contentsOf: newManga)
            self.sortManga(by: self.currentSortOption)
            self.isLoadingMore = false
        }
    }
    
    func refreshData() {
        currentPage = 1
        loadManga()
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    func clearGenreFilters() {
        selectedGenres = []
    }
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.removeAll { $0 == genre }
        } else {
            selectedGenres.append(genre)
        }
    }
    
    func sortManga(by option: SortOption) {
        currentSortOption = option
        
        switch option {
        case .popularity:
            // In a real app, this would be sorted by popularity rating
            // For now, we'll just keep the original order
            break
            
        case .latestUpdates:
            manga.sort { $0.dateAdded > $1.dateAdded }
            
        case .alphabetical:
            manga.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            
        case .status:
            manga.sort { manga1, manga2 in
                if manga1.status == manga2.status {
                    return manga1.title < manga2.title
                }
                return manga1.status.rawValue < manga2.status.rawValue
            }
        }
    }
    
    private func searchManga(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
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
    
    private func filterByGenres() {
        guard !selectedGenres.isEmpty else { return }
        
        repository.fetchMangaByGenre(genres: selectedGenres)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] results in
                    // If we're also searching, we'll need to handle that separately
                    if let self = self, !self.searchQuery.isEmpty {
                        // Apply genre filters to search results instead
                        return
                    }
                    
                    // We don't actually update manga here because we filter dynamically
                    // in the displayedManga computed property
                }
            )
            .store(in: &cancellables)
    }
}
