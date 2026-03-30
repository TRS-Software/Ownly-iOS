import SwiftUI
import Charts

struct PriceSparklineView: View {
    let dataPoints: [PricePoint]
    var height: CGFloat = 40

    struct PricePoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var isPositiveTrend: Bool {
        guard let first = dataPoints.first, let last = dataPoints.last else { return true }
        return last.value >= first.value
    }

    private var trendColor: Color {
        isPositiveTrend ? .green : .red
    }

    private var minValue: Double {
        (dataPoints.map(\.value).min() ?? 0) * 0.98
    }

    private var maxValue: Double {
        (dataPoints.map(\.value).max() ?? 1) * 1.02
    }

    @State private var appeared = false

    var body: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", minValue),
                yEnd: .value("Value", appeared ? point.value : minValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [trendColor.opacity(0.3), trendColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", appeared ? point.value : minValue)
            )
            .foregroundStyle(trendColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: minValue ... maxValue)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Mock Data

extension PriceSparklineView {
    /// Generates placeholder upward-trend data for display when no real data is available.
    static func mockUpwardTrend(days: Int = 30) -> [PricePoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [PricePoint] = []
        var value: Double = 10000

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - i), to: now) else { continue }
            // Simulate a general upward trend with small random variation
            let noise = Double.random(in: -200...300)
            value += noise
            value = max(value, 5000)
            points.append(PricePoint(date: date, value: value))
        }

        return points
    }

    /// Generates placeholder data with a negative trend.
    static func mockDownwardTrend(days: Int = 30) -> [PricePoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [PricePoint] = []
        var value: Double = 15000

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - i), to: now) else { continue }
            let noise = Double.random(in: -300...150)
            value += noise
            value = max(value, 5000)
            points.append(PricePoint(date: date, value: value))
        }

        return points
    }
}

#Preview {
    VStack(spacing: 20) {
        PriceSparklineView(dataPoints: PriceSparklineView.mockUpwardTrend())
            .padding()

        PriceSparklineView(dataPoints: PriceSparklineView.mockDownwardTrend())
            .padding()
    }
}
