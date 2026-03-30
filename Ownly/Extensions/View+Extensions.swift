import SwiftUI

extension View {
    func ownlyCard() -> some View {
        self
            .padding(16)
            .background(Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func ownlyCardShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    func ownlySection() -> some View {
        self
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func onFirstAppear(perform action: @escaping () async -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
}

private struct FirstAppearModifier: ViewModifier {
    let action: () async -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await action()
        }
    }
}

extension Date {
    func formatted(locale: Locale = .current) -> String {
        self.formatted(.dateTime.day().month().year().locale(locale))
    }

    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
