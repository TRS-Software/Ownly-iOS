import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var onboardingStore: OnboardingStore

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                SplashView()

            case .unauthenticated:
                NavigationStack {
                    LoginView()
                }

            case .guest, .authenticated:
                if !onboardingStore.isCompleted {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authState)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.ownlyBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "cube.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.ownlyPrimary)
                Text("Ownly")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                ProgressView()
                    .tint(Color.ownlyPrimary)
            }
        }
    }
}
