import Foundation

class ServiceProvider: ObservableObject {
    static let shared = ServiceProvider()
    
    // Repositories
    var mangaRepository: MangaRepository {
        getCurrentMangaRepository()
    }
    
    // Change from protocol type to concrete implementation type
    let userRepository: RealUserRepository
    
    // Services
    let apiService: APIService
    let databaseService: DatabaseService
    
    // Available repositories by source
    private var mangaDexRepository: MangaDexRepository
    private var localSourceRepository: LocalSourceRepository
    
    // Current selected source ID
    private var currentSourceId: String = "local" // Default to local source
    
    private init() {
        // Initialize services
        #if DEBUG
        if ProcessInfo.processInfo.environment["MOCK_SERVICES"] == "1" {
            // Use mock API service for testing
            apiService = MockAPIService()
        } else {
            // Use real API services for production
            apiService = MangaDexAPIService()
        }
        #else
        // Production always uses real services
        apiService = MangaDexAPIService()
        #endif
        
        // Initialize database service - use real implementation for all environments
        databaseService = UserDefaultsDatabaseService()
        
        // Initialize repositories
        mangaDexRepository = MangaDexRepository(apiService: apiService, databaseService: databaseService)
        localSourceRepository = LocalSourceRepository(databaseService: databaseService)
        
        // Initialize user repository with real implementation
        userRepository = RealUserRepository(databaseService: databaseService)
        
        // Load saved source from user preferences
        loadSavedSource()
    }
    
    // Get current repository based on selected source
    private func getCurrentMangaRepository() -> MangaRepository {
        switch currentSourceId {
        case "mangadex":
            return mangaDexRepository
        case "local":
            return localSourceRepository
        default:
            return localSourceRepository // Default to local
        }
    }
    
    // Switch source
    func switchSource(sourceId: String) {
        currentSourceId = sourceId
        saveSelectedSource(sourceId)
        objectWillChange.send()
    }
    
    // Save selected source to user preferences
    private func saveSelectedSource(_ sourceId: String) {
        UserDefaults.standard.set(sourceId, forKey: "selectedMangaSource")
    }
    
    // Load saved source from user preferences
    private func loadSavedSource() {
        if let savedSource = UserDefaults.standard.string(forKey: "selectedMangaSource") {
            currentSourceId = savedSource
        }
    }
    
    // For testing and previews
    static func createForPreview() -> ServiceProvider {
        let provider = ServiceProvider()
        return provider
    }
}
