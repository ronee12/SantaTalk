import Foundation

struct CallToken: Decodable {
    let token: String
    let conversationId: String
    let agentId: String
}

struct Entitlement: Decodable {
    let isPro: Bool
    let freeCallUsed: Bool
    let callsRemaining: Int
}

protocol BackendClientProtocol: Sendable {
    func requestCallToken(deviceId: String, language: String) async throws -> CallToken
    func fetchEntitlement(deviceId: String) async throws -> Entitlement
}

/// Talks to santa_backend. Knows nothing about ElevenLabs — it only asks for a
/// token and reports entitlement. Every failure it throws is already a
/// `SantaCallError`, so callers never have to translate a status code.
struct BackendClient: BackendClientProtocol {
    let baseURL: URL
    let devKey: String
    var session: URLSession = .shared

    private struct ErrorEnvelope: Decodable {
        struct Payload: Decodable { let reason: String }
        let error: Payload
    }

    func requestCallToken(deviceId: String, language: String) async throws -> CallToken {
        var request = URLRequest(url: baseURL.appending(path: "v1/call/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(devKey, forHTTPHeaderField: "X-Santa-Dev-Key")
        request.httpBody = try JSONEncoder().encode(["deviceId": deviceId, "language": language])
        return try await send(request)
    }

    func fetchEntitlement(deviceId: String) async throws -> Entitlement {
        var components = URLComponents(
            url: baseURL.appending(path: "v1/entitlement"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        guard let url = components?.url else { throw SantaCallError.dropped }

        var request = URLRequest(url: url)
        request.setValue(devKey, forHTTPHeaderField: "X-Santa-Dev-Key")
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // URLSession failed to reach the Worker at all — no DNS, no route,
            // airplane mode. That is the offline beat, not a dropped call.
            throw SantaCallError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw SantaCallError.dropped }

        guard (200..<300).contains(http.statusCode) else {
            let reason = try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.reason
            throw SantaCallError.from(statusCode: http.statusCode, reason: reason)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SantaCallError.dropped
        }
    }
}
