import Foundation
import Combine

class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var preferences: UserPreferences = UserPreferences()
    @Published var readingHistory: [ReadingHistoryEntry] = []
    @Published var errorMessage: String? = nil
    
    private let userRepository: UserRepository
    private let mangaRepository: MangaRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(userRepository: UserRepository = MockUserRepository(), mangaRepository: MangaRepository = MockMangaRepository()) {
        self.userRepository = userRepository
        self.mangaRepository = mangaRepository
        loadUserData()
    }
    
    private func loadUserData() {
        userRepository.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.user = user
                        self?.preferences = user.preferences
                    }
                }
            )
            .store(in: &cancellables)
        
        loadReadingHistory()
    }
    
    func loadReadingHistory() {
        mangaRepository.getReadingHistory()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] history in
                    self?.readingHistory = history
                }
            )
            .store(in: &cancellables)
    }
    
    func savePreferences() {
        userRepository.saveUserPreferences(preferences: preferences)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}
