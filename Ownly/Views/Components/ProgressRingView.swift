import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var gradientColors: [Color] = [.green, .yellow]
    var trackColor: Color = Color(.systemGray5)
    var showPercentage: Bool = true
    var customLabel: String?
    var size: CGFloat = 100

    @State private var animatedProgress: Double = 0

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Foreground ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center label
            if let label = customLabel {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.ownlyTextPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.ownlyTextPrimary)
                    .contentTransition(.numericText(countsDown: false))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.15)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

// MARK: - Concentric Rings

struct ConcentricProgressRings: View {
    let outerProgress: Double
    let innerProgress: Double
    var outerColors: [Color] = [.green, .yellow]
    var innerColors: [Color] = [.blue, .cyan]
    var outerLabel: String?
    var innerLabel: String?
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            ProgressRingView(
                progress: outerProgress,
                lineWidth: 12,
                gradientColors: outerColors,
                showPercentage: false,
                customLabel: nil,
                size: size
            )

            ProgressRingView(
                progress: innerProgress,
                lineWidth: 10,
                gradientColors: innerColors,
                showPercentage: false,
                customLabel: nil,
                size: size - 32
            )

            // Center label
            VStack(spacing: 2) {
                if let outerLabel {
                    Text(outerLabel)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(outerColors.first ?? .green)
                }
                if let innerLabel {
                    Text(innerLabel)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(innerColors.first ?? .blue)
                }
            }
            .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 30) {
        ProgressRingView(
            progress: 0.72,
            gradientColors: [.green, .yellow]
        )

        ProgressRingView(
            progress: 0.45,
            lineWidth: 8,
            gradientColors: [.orange, .red],
            customLabel: "45%",
            size: 80
        )

        ConcentricProgressRings(
            outerProgress: 0.85,
            innerProgress: 0.60,
            outerColors: [.green, .yellow],
            innerColors: [.blue, .cyan],
            outerLabel: "85%",
            innerLabel: "60%"
        )
    }
    .padding()
}
