import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var isRegistering = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.ownlyPrimary)

                    Text("Ownly")
                        .font(.largeTitle.bold())

                    Text(isRegistering
                         ? String(localized: "auth.create_account")
                         : String(localized: "auth.welcome_back"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Form
                VStack(spacing: 16) {
                    TextField(String(localized: "auth.email"), text: $authVM.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.ownly)

                    SecureField(String(localized: "auth.password"), text: $authVM.password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .textFieldStyle(.ownly)

                    Button {
                        Task {
                            if isRegistering {
                                await authVM.signUp()
                            } else {
                                await authVM.signIn()
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegistering
                                     ? String(localized: "auth.sign_up")
                                     : String(localized: "auth.sign_in"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.ownlyPrimary)
                    .disabled(authVM.isLoading)

                    if !isRegistering {
                        Button(String(localized: "auth.forgot_password")) {
                            Task { await authVM.resetPassword() }
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.ownlyPrimary)
                    }
                }
                .padding(.horizontal, 24)

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(Color.ownlySeparator)
                    Text(String(localized: "auth.or"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(Color.ownlySeparator)
                }
                .padding(.horizontal, 24)

                // OAuth
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task { await authVM.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        Task { await authVM.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text(String(localized: "auth.google_sign_in"))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.ownlySecondary)
                }
                .padding(.horizontal, 24)

                // Toggle register/login
                Button {
                    withAnimation { isRegistering.toggle() }
                } label: {
                    Text(isRegistering
                         ? String(localized: "auth.already_have_account")
                         : String(localized: "auth.no_account"))
                        .font(.footnote)
                        .foregroundStyle(Color.ownlyPrimary)
                }

                // Guest mode
                Button {
                    authVM.continueAsGuest()
                } label: {
                    Text(String(localized: "auth.continue_as_guest"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.ownlyBackground)
        .alert(String(localized: "error.title"), isPresented: $authVM.showingError) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(authVM.error ?? "")
        }
    }
}

// MARK: - Custom Styles

struct OwnlyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension TextFieldStyle where Self == OwnlyTextFieldStyle {
    static var ownly: OwnlyTextFieldStyle { OwnlyTextFieldStyle() }
}

struct OwnlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background(Color.ownlyPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OwnlySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.ownlyTextPrimary)
            .background(Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == OwnlyPrimaryButtonStyle {
    static var ownlyPrimary: OwnlyPrimaryButtonStyle { OwnlyPrimaryButtonStyle() }
}

extension ButtonStyle where Self == OwnlySecondaryButtonStyle {
    static var ownlySecondary: OwnlySecondaryButtonStyle { OwnlySecondaryButtonStyle() }
}
