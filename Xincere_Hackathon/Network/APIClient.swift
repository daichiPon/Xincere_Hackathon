import Foundation

// MARK: - エラー

enum APIError: LocalizedError {
    case unauthorized
    case notFound
    case server(String)
    case network(Error)
    case decode(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: "認証が必要です"
        case .notFound: "データが見つかりません"
        case .server(let msg): msg
        case .network: "ネットワークエラーが発生しました"
        case .decode: "データの解析に失敗しました"
        }
    }
}

// MARK: - レスポンス型

struct AuthResponse: Decodable {
    let token: String
    let userId: String
    let householdId: String
}

struct HouseholdResponse: Decodable {
    let id: String
    let childName: String
    let birthDate: Int      // milliseconds
    let isPreterm: Int      // 0 or 1
    let municipality: String
}

struct InviteResponse: Decodable {
    let code: String?
    let expiresAt: Int?     // milliseconds
}

struct InviteInfo {
    let code: String
    let expiresAt: Date
}

struct CareLogResponse: Decodable {
    let id: String
    let kind: String
    let time: Int           // milliseconds
    let detail: String
    let recordedBy: String?
}

struct MeasurementResponse: Decodable {
    let id: String
    let ageMonths: Double
    let date: Int           // milliseconds
    let heightCm: Double
    let weightKg: Double
    let headCm: Double
}

struct TaskResponse: Decodable {
    let id: String
    let title: String
    let category: String
    let dueDate: Int?       // milliseconds
    let status: String
    let assignee: String
    let summary: String
    let documents: String   // JSON 文字列
    let counter: String
    let onlineAvailable: Int
    let sourceTitle: String
    let sourceUrl: String
    let fetchedAt: String
}

struct JoinResponse: Decodable {
    let token: String
    let householdId: String
}

// MARK: - クライアント

struct APIClient {
    /// デプロイ後に実際の Workers URL に差し替える
    static var baseURL = "https://xincere-api.xincere-app.workers.dev"

    let token: String?

    init(token: String? = nil) { self.token = token }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await fetch(path, method: "GET")
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await fetch(path, method: "POST", body: body)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await fetch(path, method: "PUT", body: body)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await fetch(path, method: "PATCH", body: body)
    }

    func delete(_ path: String) async throws {
        let _: EmptyBody = try await fetch(path, method: "DELETE")
    }

    private func fetch<T: Decodable>(_ path: String, method: String, body: (any Encodable)? = nil) async throws -> T {
        guard let url = URL(string: Self.baseURL + path) else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            do { return try Self.decoder.decode(T.self, from: data) }
            catch { throw APIError.decode(error) }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let msg = (try? Self.decoder.decode(ErrorBody.self, from: data))?.error
                ?? "Server error \(http.statusCode)"
            throw APIError.server(msg)
        }
    }
}

private struct EmptyBody: Decodable {}
private struct ErrorBody: Decodable { let error: String }
