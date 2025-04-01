import Foundation
import Combine

class MangaDetailViewModel: ObservableObject {
    @Published var manga: Manga?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isFavorite: Bool = false
    
    private let repository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MangaRepository = MockMangaRepository()) {
        self.repository = repository
    }
    
    func loadMangaDetails(id: String) {
        isLoading = true
        errorMessage = nil
        
        repository.fetchMangaDetails(id: id)
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
                    self?.isFavorite = manga.isFavorite
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleFavorite() {
        guard let mangaId = manga?.id else { return }
        
        repository.toggleFavorite(mangaId: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] isFavorite in
                    self?.isFavorite = isFavorite
                    if var updatedManga = self?.manga {
                        updatedManga.isFavorite = isFavorite
                        self?.manga = updatedManga
                    }
                }
            )
            .store(in: &cancellables)
    }
}
