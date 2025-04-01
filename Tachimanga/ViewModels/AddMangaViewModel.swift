import Foundation
import Combine
import UIKit

class AddMangaViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var author: String = ""
    @Published var description: String = ""
    @Published var genres: [String] = []
    @Published var status: MangaStatus = .ongoing
    @Published var selectedImage: UIImage? = nil
    @Published var showingImagePicker = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private var localSourceRepository: LocalSourceRepository
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Get the local source repository from service provider
        guard let repository = ServiceProvider.shared.mangaRepository as? LocalSourceRepository else {
            self.localSourceRepository = LocalSourceRepository(databaseService: UserDefaultsDatabaseService())
            return
        }
        self.localSourceRepository = repository
    }
    
    func addManga(completion: @escaping (Manga) -> Void) {
        guard !self.title.isEmpty else {
            self.alertMessage = "Title is required"
            self.showingAlert = true
            return
        }
        
        self.localSourceRepository.addManga(title: self.title, coverImage: self.selectedImage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        self?.alertMessage = error.localizedDescription
                        self?.showingAlert = true
                    }
                },
                receiveValue: { [weak self] manga in
                    guard let self = self else { return }
                    // Update manga with additional info
                    var updatedManga = manga
                    updatedManga.author = self.author.isEmpty ? "Unknown" : self.author
                    updatedManga.description = self.description
                    updatedManga.genres = self.genres
                    updatedManga.status = self.status
                    
                    // Save updated info
                    _ = self.localSourceRepository.updateMangaInfo(manga: updatedManga)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { _ in
                                completion(updatedManga)
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &self.cancellables)
    }
}
