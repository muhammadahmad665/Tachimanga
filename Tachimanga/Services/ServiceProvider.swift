import Foundation

class ServiceProvider: ObservableObject {
    static let shared = ServiceProvider()
    
    // Repositories
    let mangaRepository: MangaRepository
    let userRepository: UserRepository
    
    // Services
    let apiService: APIService
    let databaseService: DatabaseService
    
    private init() {
        // Initialize services
        #if DEBUG
        if ProcessInfo.processInfo.environment["MOCK_SERVICES"] == "1" {
            // Use mock services for testing
            apiService = MockAPIService()
            databaseService = MockDatabaseService()
            mangaRepository = MockMangaRepository()
        } else {
            // Use real API services for production
            apiService = MangaDexAPIService()
            databaseService = MockDatabaseService() // We'll still use mock database service
            mangaRepository = MangaDexRepository(apiService: apiService, databaseService: databaseService)
        }
        #else
        // Production always uses real services
        apiService = MangaDexAPIService()
        databaseService = MockDatabaseService() // We'll still use mock database service for now
        mangaRepository = MangaDexRepository(apiService: apiService, databaseService: databaseService)
        #endif
        
        // Initialize repositories with services
        userRepository = MockUserRepository()
    }
    
    // For testing and previews
    static func createMockProvider() -> ServiceProvider {
        let provider = ServiceProvider()
        return provider
    }
}
