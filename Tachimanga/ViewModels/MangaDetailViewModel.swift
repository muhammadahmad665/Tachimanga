import Foundation
import Combine

class MangaDetailViewModel: ObservableObject {
    @Published var manga: Manga?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isFavorite: Bool = false
    @Published var lastReadChapterId: String? = nil
    @Published var lastReadPage: Int = 0
    @Published var readChapters: [String] = []
    @Published var hasReadingProgress: Bool = false
    
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
                    self?.loadReadingProgress(mangaId: id)
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
    
    func loadReadingProgress(mangaId: String) {
        // Load last read info
        repository.getLastReadInfo(mangaId: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] info in
                    if let info = info {
                        self?.lastReadChapterId = info.chapterId
                        self?.lastReadPage = info.page
                        self?.hasReadingProgress = true
                    } else {
                        self?.hasReadingProgress = false
                    }
                }
            )
            .store(in: &cancellables)
        
        // Load read chapters
        repository.getReadChapters(mangaId: mangaId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] chapters in
                    self?.readChapters = chapters
                    
                    // Update read status in manga object if needed
                    if let manga = self?.manga {
                        var updatedManga = manga
                        for i in 0..<updatedManga.chapters.count {
                            if chapters.contains(updatedManga.chapters[i].id) {
                                updatedManga.chapters[i].isRead = true
                            }
                        }
                        self?.manga = updatedManga
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func getLastReadChapter() -> Chapter? {
        guard let mangaId = manga?.id, let chapterId = lastReadChapterId else { return nil }
        return manga?.chapters.first { $0.id == chapterId }
    }
    
    func markChapterAsRead(chapterId: String) {
        guard let mangaId = manga?.id else { return }
        
        repository.markChapterAsRead(mangaId: mangaId, chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.loadReadingProgress(mangaId: mangaId)
                }
            )
            .store(in: &cancellables)
    }
    
    func markChapterAsUnread(chapterId: String) {
        guard let mangaId = manga?.id else { return }
        
        repository.markChapterAsUnread(mangaId: mangaId, chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.loadReadingProgress(mangaId: mangaId)
                }
            )
            .store(in: &cancellables)
    }
}
