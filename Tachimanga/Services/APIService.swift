import Foundation
import Combine

protocol APIService {
    func fetch<T: Decodable>(endpoint: String, parameters: [String: Any]?) -> AnyPublisher<T, Error>
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U) -> AnyPublisher<T, Error>
}

class MockAPIService: APIService {
    func fetch<T: Decodable>(endpoint: String, parameters: [String: Any]? = nil) -> AnyPublisher<T, Error> {
        // Simulated API response
        return Fail(error: NSError(domain: "APIService", code: 501, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
            .eraseToAnyPublisher()
    }
    
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U) -> AnyPublisher<T, Error> {
        // Simulated API response
        return Fail(error: NSError(domain: "APIService", code: 501, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
            .eraseToAnyPublisher()
    }
}

class MangaDexAPIService: APIService {
    private let baseURL = "https://api.mangadex.org"
    private let session = URLSession.shared
    
    func fetch<T: Decodable>(endpoint: String, parameters: [String: Any]? = nil) -> AnyPublisher<T, Error> {
        var components = URLComponents(string: baseURL + endpoint)
        
        if let parameters = parameters {
            components?.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }
        
        guard let url = components?.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U) -> AnyPublisher<T, Error> {
        guard let url = URL(string: baseURL + endpoint) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
