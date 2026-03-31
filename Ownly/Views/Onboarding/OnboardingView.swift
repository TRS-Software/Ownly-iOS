import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cube.fill",
            color: .blue,
            titleKey: "onboarding.welcome.title",
            descriptionKey: "onboarding.welcome.description"
        ),
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            color: .purple,
            titleKey: "onboarding.assets.title",
            descriptionKey: "onboarding.assets.description"
        ),
        OnboardingPage(
            icon: "doc.text.viewfinder",
            color: .green,
            titleKey: "onboarding.scan.title",
            descriptionKey: "onboarding.scan.description"
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            color: .orange,
            titleKey: "onboarding.ready.title",
            descriptionKey: "onboarding.ready.description"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button(String(localized: "onboarding.skip")) {
                    onboardingStore.complete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
            }

            // Pages
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 32) {
                        Spacer()

                        Image(systemName: page.icon)
                            .font(.system(size: 80))
                            .foregroundStyle(page.color)
                            .symbolEffect(.pulse, options: .repeating)

                        VStack(spacing: 12) {
                            Text(NSLocalizedString(page.titleKey, comment: ""))
                                .font(.title.bold())
                                .multilineTextAlignment(.center)

                            Text(NSLocalizedString(page.descriptionKey, comment: ""))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator + button
            VStack(spacing: 24) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.ownlyPrimary : Color.ownlyFill)
                            .frame(width: 8, height: 8)
                    }
                }

                // Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onboardingStore.complete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1
                         ? String(localized: "onboarding.next")
                         : String(localized: "onboarding.get_started"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Color.ownlyPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color.ownlyBackground)
    }
}

private struct OnboardingPage {
    let icon: String
    let color: Color
    let titleKey: String
    let descriptionKey: String
}
