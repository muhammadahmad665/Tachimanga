import Foundation
import Combine

class UserDefaultsDatabaseService: DatabaseService {
    private let defaults = UserDefaults.standard
    
    func save<T: Encodable>(object: T, key: String) -> AnyPublisher<Void, Error> {
        do {
            let data = try JSONEncoder().encode(object)
            defaults.set(data, forKey: key)
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    func load<T: Decodable>(key: String) -> AnyPublisher<T?, Error> {
        guard let data = defaults.data(forKey: key) else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        do {
            let object = try JSONDecoder().decode(T.self, from: data)
            return Just(object)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    func delete(key: String) -> AnyPublisher<Void, Error> {
        defaults.removeObject(forKey: key)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
