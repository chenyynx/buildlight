import Foundation
import Observation

/// 持有 token 与网络客户端。其它服务一律通过它拿 `GitHubClient`，
/// 换账号时只需重建一处。
@MainActor
@Observable
final class GitHubSession {
    private(set) var token: String?
    private(set) var user: Actor?
    private(set) var lastSignedInAt: Date?

    private var cachedClient: GitHubClient?

    var isSignedIn: Bool { token != nil }

    init() {
        token = Keychain.loadToken()
        if token != nil {
            cachedClient = token.map(GitHubClient.init(token:))
        }
    }

    var client: GitHubClient? { cachedClient }

    /// 校验并保存。失败时不留任何状态。
    func signIn(with rawToken: String) async throws {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.unauthorized }

        let probe = GitHubClient(token: trimmed)
        do {
            let me = try await probe.currentUser()
            Keychain.saveToken(trimmed)
            token = trimmed
            user = me
            cachedClient = probe
            lastSignedInAt = .now
        } catch {
            throw AppError.map(error)
        }
    }

    func signOut() {
        Keychain.deleteToken()
        token = nil
        user = nil
        cachedClient = nil
    }

    /// 冷启动时刷新一次身份，失败不阻断使用。
    func refreshIdentityIfNeeded() async {
        guard let client, user == nil else { return }
        user = try? await client.currentUser()
    }
}
