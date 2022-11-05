import Foundation

// Extensions used to help better streamline the main Holodex class.
// Most are private to help with having better Access Control.
extension URLSession {
    /// Uses URLRequest to set up a HTTPMethod, and implement default values for the method cases.
    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
    
    /// Decode a data object using `JSONDecoder.decode()`.
    /// - Parameters:
    ///   - type: The type of `T` that the data will decode to.
    ///   - data: `Data` input object.
    ///   - keyDecodingStrategy: Default is `.useDefaultKeys`.
    ///   - dataDecodingStrategy: Default is `.deferredToData`.
    ///   - dateDecodingStrategy: Default is `.deferredToDate`.
    /// - Returns: Decoded data of `T` type.
    private func decodeData<T: Decodable>(
        _ type: T.Type = T.self,
        with data: Data,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .deferredToData,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
    ) async throws -> T {
        let decoder = JSONDecoder()
        
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        
        let decoded = try decoder.decode(type, from: data)
        return decoded
    }
    
    /// Takes a `URL` input, along with header information, and converts it into a `URLRequest`;
    /// and fetches the data using an `Async` `Await` wrapper for the older `dataTask` handler.
    /// - Parameters:
    ///   - url: `URL` to convert to a `URLRequest`.
    ///   - method: Input can be either a `.get` or a `.post` method, with the default being `.post`.
    ///   - headers: Header data for the request that uses a `[string:string]` dictionary,
    ///   and the default is set to an empty dictionary.
    ///   - body: Body data that defaults to `nil`.
    /// - Returns: The data that was fetched typed as a `Data` object.
    private func asyncData(
        with url: URL,
        method: HTTPMethod = .post,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json"
        ]
        request.httpBody = body
        
        headers.forEach { key, value in
            request.allHTTPHeaderFields?[key] = value
        }
        
        return try await asyncData(with: request)
    }
    
    /// An Async Await wrapper for the older `dataTask` handler.
    /// - Parameter request: `URLRequest` to be fetched from.
    /// - Returns: A Data object fetched from the` URLRequest`.
    private func asyncData(with request: URLRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { (con: CheckedContinuation<Data, Error>) in
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    con.resume(throwing: error)
                } else if let data = data {
                    con.resume(returning: data)
                } else {
                    con.resume(returning: Data())
                }
            }
            
            task.resume()
        }
    }
    
    /// Decode a `URL` to the type `T` using either `asyncData()` for the Production Server;
    /// or using `decode()` for the Mock Server.
    /// - Parameters:
    ///   - type: The type of `T` that the data will decode to.
    ///   - url: The input url of type `URL` that will be fetched.
    ///   - apiKey: The API Key for use with the server.
    ///   - body: The POST body used to add parameters, defaults to nil.
    /// - Returns: The decoded object of type `T`.
    public func decodeUrl<T: Decodable>(
        _ type: T.Type = T.self,
        with url: URL,
        apiKey: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let apiKey = apiKey else { throw OpenAIError.noApiKey }
        guard let body = body else { throw OpenAIError.noBody }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        
        let data = try await self.asyncData(with: url, headers: ["Authorization": "Bearer \(apiKey)"], body: jsonData)
        
        return try await self.decodeData(
            with: data,
            keyDecodingStrategy: .useDefaultKeys
        )
    }
}