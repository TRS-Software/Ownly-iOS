import SwiftUI
import Charts

struct FinanceView: View {
    let asset: Asset

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var records: [MaintenanceRecord] = []
    @State private var isLoading = true

    private var maintenanceRepo: MaintenanceRepository { MaintenanceRepository.shared }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    roiSection
                    totalCostCard
                    costByYearSection
                    costByTypeSection

                    if asset.assetType.isRentable {
                        monthlyIncomeSection
                    }

                    Spacer(minLength: 40)
                }
            }
            .padding()
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "finance.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await maintenanceRepo.fetchForAsset(asset.id)
            records = maintenanceRepo.recordsForAsset(asset.id)
            isLoading = false
        }
    }

    // MARK: - ROI Section

    private var roiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "finance.roi"), systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            if let purchase = asset.purchasePriceCents {
                let currentValue = asset.estimatedValueCents ?? purchase
                let profit = currentValue - purchase
                let percentage = purchase > 0 ? (Double(profit) / Double(purchase)) * 100.0 : 0.0
                let isPositive = profit >= 0

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "finance.purchase_price"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settingsStore.formatCurrency(purchase, code: asset.currency))
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "finance.current_value"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settingsStore.formatCurrency(currentValue, code: asset.currency))
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPositive
                             ? String(localized: "finance.profit")
                             : String(localized: "finance.loss"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(settingsStore.formatCurrency(abs(profit), code: asset.currency))
                            .font(.title3.bold())
                            .foregroundStyle(isPositive ? .green : .red)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        Text(abs(percentage).formattedPercent())
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(isPositive ? .green : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isPositive ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())
                }
            } else {
                Text(String(localized: "finance.no_purchase_price"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ownlyCard()
    }

    // MARK: - Total Cost Card

    private var totalCostCard: some View {
        let totalCents = records.compactMap(\.costCents).reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "finance.total_maintenance_cost"), systemImage: "wrench.and.screwdriver.fill")
                .font(.headline)

            Text(settingsStore.formatCurrency(totalCents, code: asset.currency))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ownlyPrimary)

            Text(String(localized: "finance.from_records \(records.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ownlyCard()
    }

    // MARK: - Cost by Year (Bar Chart)

    private var costByYearSection: some View {
        let yearlyData = costsByYear

        return VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "finance.cost_by_year"), systemImage: "chart.bar.fill")
                .font(.headline)

            if yearlyData.isEmpty {
                Text(String(localized: "finance.no_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(yearlyData) { item in
                    BarMark(
                        x: .value(String(localized: "finance.year"), item.year),
                        y: .value(String(localized: "finance.cost"), item.amountDouble)
                    )
                    .foregroundStyle(Color.ownlyPrimary.gradient)
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let amount = value.as(Double.self) {
                            AxisValueLabel {
                                Text(amount.formattedCompact())
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
            }
        }
        .ownlyCard()
    }

    // MARK: - Cost by Type (Sector Chart)

    private var costByTypeSection: some View {
        let typeData = costsByType

        return VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "finance.cost_by_type"), systemImage: "chart.pie.fill")
                .font(.headline)

            if typeData.isEmpty {
                Text(String(localized: "finance.no_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(typeData) { item in
                    SectorMark(
                        angle: .value(item.type.displayName, item.amountDouble),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.type.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(typeData) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.type.color)
                                .frame(width: 10, height: 10)
                            Text(item.type.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settingsStore.formatCurrency(item.totalCents, code: asset.currency))
                                .font(.caption.bold())
                        }
                    }
                }
            }
        }
        .ownlyCard()
    }

    // MARK: - Monthly Income (Rental)

    @ViewBuilder
    private var monthlyIncomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "finance.monthly_income"), systemImage: "banknote.fill")
                .font(.headline)

            let monthlyRentCents = rentalMonthlyRentCents
            let monthlyExpenseCents = averageMonthlyExpenseCents

            if monthlyRentCents > 0 {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "finance.rental_income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settingsStore.formatCurrency(monthlyRentCents, code: asset.currency))
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "finance.avg_expenses"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settingsStore.formatCurrency(monthlyExpenseCents, code: asset.currency))
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                let netIncome = monthlyRentCents - monthlyExpenseCents
                let isPositive = netIncome >= 0

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "finance.net_monthly"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settingsStore.formatCurrency(abs(netIncome), code: asset.currency))
                            .font(.title3.bold())
                            .foregroundStyle(isPositive ? .green : .red)
                    }

                    Spacer()

                    Text(String(localized: "finance.annual"))
                    Text(settingsStore.formatCurrency(abs(netIncome) * 12, code: asset.currency))
                        .font(.subheadline.bold())
                        .foregroundStyle(isPositive ? .green : .red)
                }
            } else {
                Text(String(localized: "finance.no_rental_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ownlyCard()
    }

    // MARK: - Computed Data

    private var costsByYear: [YearlyCost] {
        let cal = Calendar.current
        var grouped: [String: Int] = [:]

        for record in records {
            guard let cost = record.costCents else { continue }
            let year = String(cal.component(.year, from: record.performedAt))
            grouped[year, default: 0] += cost
        }

        return grouped
            .map { YearlyCost(year: $0.key, totalCents: $0.value) }
            .sorted { $0.year < $1.year }
    }

    private var costsByType: [TypeCost] {
        var grouped: [MaintenanceType: Int] = [:]

        for record in records {
            guard let cost = record.costCents else { continue }
            grouped[record.type, default: 0] += cost
        }

        return grouped
            .map { TypeCost(type: $0.key, totalCents: $0.value) }
            .sorted { $0.totalCents > $1.totalCents }
    }

    private var rentalMonthlyRentCents: Int {
        if let rentData = asset.metadata["rental"],
           let rentStr = rentData.stringValue,
           let data = rentStr.data(using: .utf8),
           let rental = try? JSONDecoder().decode(RentalMetadata.self, from: data) {
            return rental.totalMonthlyRentCents ?? rental.tenants.compactMap(\.monthlyRentCents).reduce(0, +)
        }
        if let rentCents = asset.metadataInt("monthly_rent_cents") {
            return rentCents
        }
        return 0
    }

    private var averageMonthlyExpenseCents: Int {
        let totalCents = records.compactMap(\.costCents).reduce(0, +)
        guard !records.isEmpty else { return 0 }
        let cal = Calendar.current
        let dates = records.map(\.performedAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return 0 }
        let months = max(1, cal.dateComponents([.month], from: earliest, to: latest).month ?? 1)
        return totalCents / months
    }
}

// MARK: - Data Models

private struct YearlyCost: Identifiable {
    let year: String
    let totalCents: Int
    var id: String { year }
    var amountDouble: Double { Double(totalCents) / 100.0 }
}

private struct TypeCost: Identifiable {
    let type: MaintenanceType
    let totalCents: Int
    var id: String { type.rawValue }
    var amountDouble: Double { Double(totalCents) / 100.0 }
}
