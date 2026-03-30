import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var showingError = false

    private let auth = AuthService.shared

    func observeAuthState() async {
        // Check existing session first
        if let session = try? await auth.getCurrentSession() {
            AppState.shared?.authState = .authenticated(userId: session.user.id.uuidString)
            return
        }

        // Listen for changes
        for await (event, session) in auth.observeAuthChanges() {
            switch event {
            case .signedIn:
                if let userId = session?.user.id.uuidString {
                    withAnimation {
                        AppState.shared?.authState = .authenticated(userId: userId)
                    }
                }
            case .signedOut:
                withAnimation {
                    AppState.shared?.authState = .unauthenticated
                }
            default:
                break
            }
        }
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            showError(String(localized: "error.auth.fill_fields"))
            return
        }

        isLoading = true
        do {
            try await auth.signIn(email: email, password: password)
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            showError(String(localized: "error.auth.fill_fields"))
            return
        }

        guard password.count >= 6 else {
            showError(String(localized: "error.auth.password_too_short"))
            return
        }

        isLoading = true
        do {
            try await auth.signUp(email: email, password: password)
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        do {
            try await auth.signInWithGoogle()
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                do {
                    try await self.auth.signInWithApple(credential: credential)
                } catch {
                    showError(error.localizedDescription)
                }
            }
        case .failure(let error):
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    func continueAsGuest() {
        withAnimation {
            AppState.shared?.authState = .guest
        }
    }

    func signOut() async {
        do {
            try await auth.signOut()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func resetPassword() async {
        guard !email.isEmpty else {
            showError(String(localized: "error.auth.enter_email"))
            return
        }
        isLoading = true
        do {
            try await auth.resetPassword(email: email)
            showError(String(localized: "auth.reset_email_sent"))
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    private func showError(_ message: String) {
        error = message
        showingError = true
    }
}

// Hacky but simple way to access AppState from VM
extension AppState {
    private static var _shared: AppState?
    static var shared: AppState? {
        get { _shared }
        set { _shared = newValue }
    }

    func registerShared() {
        AppState._shared = self
    }
}
