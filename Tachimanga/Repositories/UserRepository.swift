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
