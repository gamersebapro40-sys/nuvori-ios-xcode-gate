import Foundation

enum NUVORINativeAuthError: Error {
    case invalidResponse
    case httpStatus(Int)
    case credentialStoreRequired
    case missingRefreshToken
}

struct NUVORINativeAuthUser: Decodable {
    let id: String
    let email: String?
}

struct NUVORINativeAuthSession: Decodable {
    let authenticated: Bool
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Double?
    let tokenType: String?
    let user: NUVORINativeAuthUser?
}

struct NUVORIAPIClient {
    let baseURL: URL
    let credentialStore: NUVORIKeychainStore?

    init(baseURL: URL, credentialStore: NUVORIKeychainStore? = nil) {
        self.baseURL = baseURL
        self.credentialStore = credentialStore
    }

    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = credentialStore?.readAccessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func replacingAuthorization(in request: URLRequest) -> URLRequest {
        var next = request
        next.setValue(nil, forHTTPHeaderField: "Authorization")
        if let token = credentialStore?.readAccessToken(), !token.isEmpty {
            next.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return next
    }

    private func jsonPOST(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw NUVORINativeAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw NUVORINativeAuthError.httpStatus(http.statusCode) }
    }

    private func decodeNativeSession(_ data: Data, response: URLResponse) throws -> NUVORINativeAuthSession {
        try requireSuccess(response)
        return try JSONDecoder().decode(NUVORINativeAuthSession.self, from: data)
    }

    func loginNative(email: String, password: String) async throws -> NUVORINativeAuthSession {
        guard let credentialStore else { throw NUVORINativeAuthError.credentialStoreRequired }
        let request = try jsonPOST(path: "api/auth/native/login", body: ["email": email, "password": password])
        let (data, response) = try await URLSession.shared.data(for: request)
        let session = try decodeNativeSession(data, response: response)
        try credentialStore.saveTokenPair(accessToken: session.accessToken, refreshToken: session.refreshToken)
        return session
    }

    @discardableResult
    func refreshNativeSession() async throws -> NUVORINativeAuthSession {
        guard let credentialStore else { throw NUVORINativeAuthError.credentialStoreRequired }
        guard let refreshToken = credentialStore.readRefreshToken(), !refreshToken.isEmpty else {
            throw NUVORINativeAuthError.missingRefreshToken
        }
        let request = try jsonPOST(path: "api/auth/native/refresh", body: ["refreshToken": refreshToken])
        let (data, response) = try await URLSession.shared.data(for: request)
        let session = try decodeNativeSession(data, response: response)
        try credentialStore.saveTokenPair(accessToken: session.accessToken, refreshToken: session.refreshToken)
        return session
    }

    func logoutNative(global: Bool = false) async throws {
        guard let credentialStore else { throw NUVORINativeAuthError.credentialStoreRequired }
        defer { try? credentialStore.deleteTokenPair() }

        var request = authorizedRequest(for: baseURL.appendingPathComponent("api/auth/native/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["global": global])
        let (_, response) = try await URLSession.shared.data(for: request)
        try requireSuccess(response)
    }

    private func authenticatedData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let first = try await URLSession.shared.data(for: request)
        guard let http = first.1 as? HTTPURLResponse,
              http.statusCode == 401,
              credentialStore?.readRefreshToken()?.isEmpty == false else {
            return first
        }

        _ = try await refreshNativeSession()
        let retry = replacingAuthorization(in: request)
        return try await URLSession.shared.data(for: retry)
    }

    func searchFoods(_ query: String) async throws -> [FoodResult] {
        var c = URLComponents(url: baseURL.appendingPathComponent("api/food/search"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "20")]
        let request = authorizedRequest(for: c.url!)
        let (data, response) = try await authenticatedData(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        struct Envelope: Decodable { let foods: [FoodResult] }
        return try JSONDecoder().decode(Envelope.self, from: data).foods
    }
}
