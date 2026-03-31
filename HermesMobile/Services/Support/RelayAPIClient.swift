import Foundation

@MainActor
final class RelayAPIClient {
    private struct Envelope<T: Decodable>: Decodable {
        let data: T
    }

    private struct ErrorEnvelope: Decodable {
        struct ErrorPayload: Decodable {
            let code: String
            let message: String
            let retryable: Bool
        }

        let error: ErrorPayload
    }

    enum ClientError: LocalizedError {
        case invalidURL(String)
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                "Invalid relay URL: \(url)"
            case .requestFailed(let message):
                message
            }
        }
    }

    private let baseURLProvider: @MainActor () -> String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURLProvider: @escaping @MainActor () -> String,
        session: URLSession = .shared
    ) {
        self.baseURLProvider = baseURLProvider
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<T: Decodable>(
        path: String,
        accessToken: String? = nil
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", accessToken: accessToken, body: nil)
        return try await send(request)
    }

    func post<Body: Encodable, T: Decodable>(
        path: String,
        body: Body,
        accessToken: String? = nil
    ) async throws -> T {
        let requestBody = try encoder.encode(body)
        let request = try makeRequest(
            path: path,
            method: "POST",
            accessToken: accessToken,
            body: requestBody
        )
        return try await send(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        accessToken: String?,
        body: Data?
    ) throws -> URLRequest {
        let path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseURLString = baseURLProvider().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(baseURLString)/\(path)") else {
            throw ClientError.invalidURL(baseURLString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        guard let httpResponse else {
            throw ClientError.requestFailed("Relay returned an invalid response.")
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if let errorEnvelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
                throw ClientError.requestFailed(errorEnvelope.error.message)
            }

            throw ClientError.requestFailed("Relay request failed with status \(httpResponse.statusCode).")
        }

        return try decoder.decode(Envelope<T>.self, from: data).data
    }
}
