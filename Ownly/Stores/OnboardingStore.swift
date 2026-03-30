import SwiftUI

@MainActor
final class OnboardingStore: ObservableObject {
    @AppStorage("onboardingCompleted") var isCompleted: Bool = false
    @AppStorage("introSeen") var introSeen: Bool = false
    @AppStorage("onboardingStep") var currentStep: Int = 0
    @AppStorage("demoHidden") var demoHidden: Bool = false

    func complete() {
        isCompleted = true
    }

    func reset() {
        isCompleted = false
        currentStep = 0
    }
}
