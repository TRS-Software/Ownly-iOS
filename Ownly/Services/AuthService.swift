import Foundation
import Supabase
import AuthenticationServices

final class AuthService {
    static let shared = AuthService()
    private let supabase = SupabaseService.shared

    private init() {}

    // MARK: - Email Auth

    func signIn(email: String, password: String) async throws {
        try await supabase.client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.client.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.client.auth.signOut()
    }

    // MARK: - OAuth

    func signInWithGoogle() async throws {
        try await supabase.client.auth.signInWithOAuth(provider: .google) { url in
            await UIApplication.shared.open(url)
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }

        try await supabase.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: tokenString)
        )
    }

    // MARK: - Session

    func getCurrentSession() async throws -> Session {
        try await supabase.client.auth.session
    }

    func getCurrentUser() async throws -> User {
        try await supabase.client.auth.session.user
    }

    func observeAuthChanges() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in supabase.client.auth.authStateChanges {
                    continuation.yield((event: event, session: session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        try await supabase.client.auth.resetPasswordForEmail(email)
    }
}

enum AuthError: LocalizedError {
    case invalidToken
    case noSession
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken: return String(localized: "error.auth.invalid_token")
        case .noSession: return String(localized: "error.auth.no_session")
        case .unknownError(let msg): return msg
        }
    }
}
