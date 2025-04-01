import Foundation
import Combine

protocol UserRepository {
    func getCurrentUser() -> AnyPublisher<User?, Error>
    func saveUserPreferences(preferences: UserPreferences) -> AnyPublisher<Void, Error>
    func getUserPreferences() -> AnyPublisher<UserPreferences, Error>
}

class MockUserRepository: UserRepository {
    private var currentUser = User.sample
    
    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return Just(currentUser)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func saveUserPreferences(preferences: UserPreferences) -> AnyPublisher<Void, Error> {
        currentUser.preferences = preferences
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getUserPreferences() -> AnyPublisher<UserPreferences, Error> {
        return Just(currentUser.preferences)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

class RealUserRepository: UserRepository {
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()
    private let userKey = "current_user"
    private let preferencesKey = "user_preferences"
    
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }
    
    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return databaseService.load(key: userKey)
    }
    
    func saveUserPreferences(preferences: UserPreferences) -> AnyPublisher<Void, Error> {
        return getCurrentUser()
            .flatMap { [weak self] user -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "UserRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Repository deallocated"]))
                        .eraseToAnyPublisher()
                }
                
                var updatedUser = user ?? User(id: UUID().uuidString, username: "User")
                updatedUser.preferences = preferences
                
                return self.databaseService.save(object: updatedUser, key: self.userKey)
            }
            .eraseToAnyPublisher()
    }
    
    func getUserPreferences() -> AnyPublisher<UserPreferences, Error> {
        return getCurrentUser()
            .map { user -> UserPreferences in
                return user?.preferences ?? UserPreferences()
            }
            .eraseToAnyPublisher()
    }
}
