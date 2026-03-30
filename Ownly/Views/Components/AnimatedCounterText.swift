import SwiftUI

struct AnimatedCounterText: View {
    let valueCents: Int
    let currencyCode: String?
    let settings: SettingsStore

    var font: Font = .system(size: 34, weight: .bold, design: .rounded)
    var foregroundColor: Color = .ownlyTextPrimary

    private var formattedValue: String {
        settings.formatCurrency(valueCents, code: currencyCode)
    }

    var body: some View {
        Text(formattedValue)
            .font(font)
            .foregroundStyle(foregroundColor)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .contentTransition(.numericText(countsDown: false))
            .animation(.spring(duration: 0.5, bounce: 0.2), value: valueCents)
    }
}

#Preview {
    @Previewable @State var value = 123456

    VStack(spacing: 20) {
        AnimatedCounterText(
            valueCents: value,
            currencyCode: "EUR",
            settings: SettingsStore()
        )

        Button("Increase") {
            value += Int.random(in: 1000...10000)
        }

        Button("Decrease") {
            value -= Int.random(in: 1000...5000)
        }
    }
    .padding()
}
