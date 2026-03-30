import SwiftUI
import Charts

struct PriceHistoryChartView: View {
    let asset: Asset

    @State private var selectedPeriod: TimePeriod = .oneMonth
    @State private var dataPoints: [PricePoint] = []
    @State private var selectedPoint: PricePoint?
    @State private var appeared = false

    enum TimePeriod: String, CaseIterable, Identifiable {
        case oneDay = "1D"
        case oneWeek = "1W"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case oneYear = "1Y"
        case all = "ALL"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .oneDay: return 1
            case .oneWeek: return 7
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .oneYear: return 365
            case .all: return 730
            }
        }
    }

    struct PricePoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    // MARK: - Computed

    private var isPositiveTrend: Bool {
        guard let first = dataPoints.first, let last = dataPoints.last else { return true }
        return last.value >= first.value
    }

    private var trendColor: Color {
        isPositiveTrend ? .green : .red
    }

    private var currentPrice: Double? {
        if let selected = selectedPoint {
            return selected.value
        }
        return dataPoints.last?.value
    }

    private var priceChange: Double? {
        guard let first = dataPoints.first?.value, let last = currentPrice, first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    private var priceChangeCents: Int? {
        guard let first = dataPoints.first?.value, let last = currentPrice else { return nil }
        return Int((last - first) * 100)
    }

    private var minValue: Double {
        (dataPoints.map(\.value).min() ?? 0) * 0.98
    }

    private var maxValue: Double {
        (dataPoints.map(\.value).max() ?? 1) * 1.02
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Price + Change
            priceHeader

            // Chart
            chartView
                .frame(height: 220)

            // Period selector
            periodSelector
        }
        .padding()
        .background(Color.ownlySecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            generateMockData(for: selectedPeriod)
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedPoint = nil
                generateMockData(for: newPeriod)
            }
        }
    }

    // MARK: - Price Header

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let price = currentPrice {
                Text(formatPrice(price))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ownlyTextPrimary)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(duration: 0.3), value: selectedPoint?.id)
            }

            HStack(spacing: 6) {
                if let change = priceChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%+.2f%%", change))
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(change >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((change >= 0 ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())
                }

                if selectedPoint != nil {
                    Text(selectedPoint!.date.formatted(.dateTime.month().day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(selectedPeriod.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", minValue),
                yEnd: .value("Value", appeared ? point.value : minValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [trendColor.opacity(0.3), trendColor.opacity(0.02)],
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
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            if let selected = selectedPoint, selected.id == point.id {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(Color.ownlyTextSecondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .symbol {
                    Circle()
                        .fill(trendColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: trendColor.opacity(0.4), radius: 4)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: minValue ... maxValue)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let xPosition = drag.location.x
                                guard let date: Date = proxy.value(atX: xPosition) else { return }
                                // Find closest data point
                                if let closest = dataPoints.min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                }) {
                                    selectedPoint = closest
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                }
                            }
                    )
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimePeriod.allCases) { period in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(selectedPeriod == period ? .white : Color.ownlyTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedPeriod == period {
                                Capsule()
                                    .fill(trendColor)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.ownlyFill)
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func formatPrice(_ price: Double) -> String {
        let cents = Int(price * 100)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = asset.currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "\(price)"
    }

    /// Generates mock price data for the chart. Replace with real API data when available.
    private func generateMockData(for period: TimePeriod) {
        let calendar = Calendar.current
        let now = Date()
        let days = period.days
        let pointCount = min(days, 100)
        var points: [PricePoint] = []
        var value: Double = 150.0

        let intervalSeconds = (Double(days) * 86400) / Double(pointCount)

        for i in 0..<pointCount {
            let offset = -Double(pointCount - 1 - i) * intervalSeconds
            let date = now.addingTimeInterval(offset)

            // Random walk with slight upward bias
            let volatility: Double = period == .oneDay ? 0.5 : 2.0
            let noise = Double.random(in: -volatility...volatility * 1.1)
            value += noise
            value = max(value, 50)

            points.append(PricePoint(date: date, value: value))
        }

        dataPoints = points
    }
}

#Preview {
    ScrollView {
        PriceHistoryChartView(
            asset: Asset(
                userId: UUID(),
                assetType: .stocks,
                name: "Apple Inc.",
                metadata: ["ticker": AnyCodable("AAPL")],
                currency: "USD"
            )
        )
        .padding()
    }
    .background(Color.ownlyBackground)
}
