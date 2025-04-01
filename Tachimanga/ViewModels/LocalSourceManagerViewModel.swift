import Foundation
import Combine
import UIKit

class LocalSourceManagerViewModel: ObservableObject {
    @Published var localManga: [Manga] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showingFileImporter = false
    @Published var showingAlert = false
    @Published var alertTitle = ""
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
    
    func loadLocalManga() {
        isLoading = true
        
        localSourceRepository.fetchPopularManga()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.showAlert(title: "Error", message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] manga in
                    self?.localManga = manga.sorted(by: { $0.title < $1.title })
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteManga(at indexSet: IndexSet) {
        // Ask for confirmation first
        showAlert(title: "Delete Manga?", message: "This will delete all chapters and data for this manga. This action cannot be undone.")
        
        // In a real app, implement the deletion logic
        guard let index = indexSet.first, index < localManga.count else { return }
        
        // Remove the manga from the array
        localManga.remove(at: index)
    }
    
    func importFromFiles() {
        showingFileImporter = true
    }
    
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else {
                showAlert(title: "Import Failed", message: "Could not access the selected folder.")
                return
            }
            
            // Process the folder - in a real app you would import manga from the folder
            showAlert(title: "Import Started", message: "Importing manga from \(url.lastPathComponent)")
            url.stopAccessingSecurityScopedResource()
            
            // Reload manga list
            loadLocalManga()
            
        case .failure(let error):
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}
