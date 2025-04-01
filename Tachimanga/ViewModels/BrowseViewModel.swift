import Foundation
import Combine

class BrowseViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    
    // Filter options
    @Published var selectedGenres: [String] = []
    @Published var selectedStatus: [MangaStatus] = []
    @Published var selectedLanguages: [String] = []
    @Published var sortOption: MangaSortOption = .popularity
    
    // Manga data
    @Published var manga: [Manga] = []
    @Published var searchResults: [Manga] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentPage: Int = 1
    
    // Source management
    @Published var currentSource: MangaSource?
    @Published var showSourceSelector = false
    @Published var showAdvancedFilters = false
    
    // Has active filters indicator
    @Published var activeFilterCount: Int = 0
    
    // Add refresh control coordinator - initialize it later to avoid 'self' capture issues
    lazy var refreshControl: RefreshControlCoordinator = {
        return RefreshControlCoordinator(action: { [weak self] in
            self?.refreshData()
        })
    }()
    
    var displayedManga: [Manga] {
        if !searchQuery.isEmpty {
            return searchResults
        } else {
            return manga
        }
    }
    
    private let repository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MangaRepository = ServiceProvider.shared.mangaRepository) {
        self.repository = repository
        
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
        
        // Monitor filter changes to update active filter count
        Publishers.CombineLatest3($selectedGenres, $selectedStatus, $selectedLanguages)
            .map { genres, status, languages in
                return genres.count + status.count + languages.count
            }
            .assign(to: &$activeFilterCount)
        
        // Load current source
        loadCurrentSource()
    }
    
    func loadManga() {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        loadMangaWithFilters()
    }
    
    func loadMoreManga() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        loadMangaWithFilters()
    }
    
    func refreshData() {
        currentPage = 1
        loadManga()
    }
    
    func clearFilters() {
        selectedGenres = []
        selectedStatus = []
        selectedLanguages = []
        sortOption = .popularity
    }
    
    func handleSourceChanged(_ source: MangaSource) {
        currentSource = source
        // Reload data with the new source
        clearFilters()
        refreshData()
    }
    
    private func loadMangaWithFilters() {
        let page = currentPage
        let genres = selectedGenres.isEmpty ? nil : selectedGenres
        let status = selectedStatus.isEmpty ? nil : selectedStatus
        let languages = selectedLanguages.isEmpty ? nil : selectedLanguages
        
        repository.fetchMangaWithFilters(
            genres: genres,
            status: status,
            languages: languages,
            sortOption: sortOption,
            page: page,
            itemsPerPage: 20
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if let self = self {
                    if self.currentPage == 1 {
                        self.isLoading = false
                    } else {
                        self.isLoadingMore = false
                    }
                    
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                }
            },
            receiveValue: { [weak self] mangaPage in
                guard let self = self else { return }
                
                if self.currentPage == 1 {
                    self.manga = mangaPage.manga
                } else {
                    self.manga.append(contentsOf: mangaPage.manga)
                }
                
                self.isLoading = false
                self.isLoadingMore = false
            }
        )
        .store(in: &cancellables)
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
    
    private func loadCurrentSource() {
        repository.getCurrentSource()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] source in
                    self?.currentSource = source
                }
            )
            .store(in: &cancellables)
    }
}
