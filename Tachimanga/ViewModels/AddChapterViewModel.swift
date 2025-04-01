import Foundation
import Combine
import UIKit

class AddChapterViewModel: ObservableObject {
    @Published var chapterNumber: Double
    @Published var chapterTitle: String = ""
    @Published var selectedImages: [UIImage] = []
    @Published var showingImagePicker = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private var localSourceRepository: LocalSourceRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(initialChapterNumber: Double = 1.0) {
        self.chapterNumber = initialChapterNumber
        
        // Get the local source repository from service provider
        guard let repository = ServiceProvider.shared.mangaRepository as? LocalSourceRepository else {
            self.localSourceRepository = LocalSourceRepository(databaseService: UserDefaultsDatabaseService())
            return
        }
        self.localSourceRepository = repository
    }
    
    func addChapter(to manga: Manga, completion: @escaping (Chapter) -> Void) {
        guard !selectedImages.isEmpty else {
            alertMessage = "You must select at least one image for the chapter"
            showingAlert = true
            return
        }
        
        localSourceRepository.addChapter(
            mangaId: manga.id,
            chapterNumber: chapterNumber,
            title: chapterTitle.isEmpty ? nil : chapterTitle,
            images: selectedImages
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.alertMessage = error.localizedDescription
                    self?.showingAlert = true
                }
            },
            receiveValue: { chapter in
                completion(chapter)
            }
        )
        .store(in: &cancellables)
    }
}
