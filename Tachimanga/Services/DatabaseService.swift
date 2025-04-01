import Foundation
import Combine

protocol DatabaseService {
    func save<T: Encodable>(object: T, key: String) -> AnyPublisher<Void, Error>
    func load<T: Decodable>(key: String) -> AnyPublisher<T?, Error>
    func delete(key: String) -> AnyPublisher<Void, Error>
}

class MockDatabaseService: DatabaseService {
    private var storage: [String: Data] = [:]
    
    func save<T: Encodable>(object: T, key: String) -> AnyPublisher<Void, Error> {
        do {
            let data = try JSONEncoder().encode(object)
            storage[key] = data
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    func load<T: Decodable>(key: String) -> AnyPublisher<T?, Error> {
        guard let data = storage[key] else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return Just(decoded)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    func delete(key: String) -> AnyPublisher<Void, Error> {
        storage.removeValue(forKey: key)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
