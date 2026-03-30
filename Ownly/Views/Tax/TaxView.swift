import SwiftUI

struct TaxView: View {
    let asset: Asset

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var records: [MaintenanceRecord] = []
    @State private var isLoading = true

    // Input Form State
    @State private var usageType: UsageType = .rented
    @State private var buildingSharePercent: Double = 80
    @State private var hasLoan: Bool = false
    @State private var annualGrossIncome: String = ""
    @State private var filingStatus: FilingStatus = .single
    @State private var churchTax: Bool = false

    private var maintenanceRepo: MaintenanceRepository { MaintenanceRepository.shared }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    inputFormSection
                    taxSavingsCard
                    deductionBreakdownSection
                    taxTipsSection
                    documentChecklistSection

                    Spacer(minLength: 40)
                }
            }
            .padding()
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "tax.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await maintenanceRepo.fetchForAsset(asset.id)
            records = maintenanceRepo.recordsForAsset(asset.id)
            isLoading = false
        }
    }

    // MARK: - Input Form

    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(String(localized: "tax.input"), systemImage: "slider.horizontal.3")
                .font(.headline)

            // Usage Type
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "tax.usage_type"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker(String(localized: "tax.usage_type"), selection: $usageType) {
                    ForEach(UsageType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Building Share
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "tax.building_share"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(buildingSharePercent))%")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                Slider(value: $buildingSharePercent, in: 0...100, step: 5)
                    .tint(Color.ownlyPrimary)
                Text(String(localized: "tax.building_share_hint"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Has Loan
            Toggle(isOn: $hasLoan) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "tax.has_loan"))
                        .font(.subheadline)
                    Text(String(localized: "tax.has_loan_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(Color.ownlyPrimary)

            // Annual Gross Income
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "tax.annual_gross_income"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(String(localized: "tax.income_placeholder"), text: $annualGrossIncome)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            // Filing Status
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "tax.filing_status"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker(String(localized: "tax.filing_status"), selection: $filingStatus) {
                    ForEach(FilingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Church Tax
            Toggle(isOn: $churchTax) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "tax.church_tax"))
                        .font(.subheadline)
                    Text(String(localized: "tax.church_tax_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(Color.ownlyPrimary)
        }
        .ownlyCard()
    }

    // MARK: - Tax Savings Card

    private var taxSavingsCard: some View {
        let calc = taxCalculation

        return VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "tax.estimated_savings"), systemImage: "eurosign.circle.fill")
                .font(.headline)

            Text(settingsStore.formatCurrency(calc.totalSavingsCents, code: asset.currency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            Text(String(localized: "tax.per_year"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Breakdown
            TaxBreakdownRow(
                label: String(localized: "tax.income_tax_savings"),
                amount: calc.incomeTaxSavingsCents,
                currency: asset.currency
            )

            TaxBreakdownRow(
                label: String(localized: "tax.soli_savings") + " (5,5%)",
                amount: calc.soliSavingsCents,
                currency: asset.currency
            )

            if churchTax {
                TaxBreakdownRow(
                    label: String(localized: "tax.church_tax_savings") + " (8-9%)",
                    amount: calc.churchTaxSavingsCents,
                    currency: asset.currency
                )
            }
        }
        .ownlyCard()
    }

    // MARK: - Deduction Breakdown

    private var deductionBreakdownSection: some View {
        let calc = taxCalculation

        return VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "tax.deductions"), systemImage: "list.bullet.rectangle.fill")
                .font(.headline)

            switch usageType {
            case .rented:
                DeductionRow(
                    icon: "building.2.fill",
                    label: String(localized: "tax.afa_depreciation"),
                    detail: String(localized: "tax.afa_detail"),
                    amount: calc.afaCents,
                    currency: asset.currency
                )
                DeductionRow(
                    icon: "wrench.fill",
                    label: String(localized: "tax.maintenance_costs"),
                    detail: String(localized: "tax.maintenance_deductible"),
                    amount: calc.maintenanceCents,
                    currency: asset.currency
                )
                DeductionRow(
                    icon: "shield.fill",
                    label: String(localized: "tax.insurance"),
                    detail: String(localized: "tax.insurance_deductible"),
                    amount: calc.insuranceCents,
                    currency: asset.currency
                )
                DeductionRow(
                    icon: "person.fill",
                    label: String(localized: "tax.management_fees"),
                    detail: String(localized: "tax.management_deductible"),
                    amount: calc.managementCents,
                    currency: asset.currency
                )

            case .ownerOccupied:
                DeductionRow(
                    icon: "hammer.fill",
                    label: String(localized: "tax.para_35a"),
                    detail: String(localized: "tax.para_35a_detail"),
                    amount: calc.handwerkerCents,
                    currency: asset.currency
                )
                DeductionRow(
                    icon: "leaf.fill",
                    label: String(localized: "tax.para_35c"),
                    detail: String(localized: "tax.para_35c_detail"),
                    amount: calc.energeticCents,
                    currency: asset.currency
                )

            case .tenant:
                DeductionRow(
                    icon: "desktopcomputer",
                    label: String(localized: "tax.home_office"),
                    detail: String(localized: "tax.home_office_detail"),
                    amount: calc.homeOfficeCents,
                    currency: asset.currency
                )
            }

            Divider()

            HStack {
                Text(String(localized: "tax.total_deductions"))
                    .font(.subheadline.bold())
                Spacer()
                Text(settingsStore.formatCurrency(calc.totalDeductionsCents, code: asset.currency))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyPrimary)
            }
        }
        .ownlyCard()
    }

    // MARK: - Tax Tips

    private var taxTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "tax.tips"), systemImage: "lightbulb.fill")
                .font(.headline)

            ForEach(tipsForUsageType, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .ownlyCard()
    }

    // MARK: - Document Checklist

    private var documentChecklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "tax.document_checklist"), systemImage: "checklist")
                .font(.headline)

            Text(String(localized: "tax.keep_documents"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(documentsForUsageType, id: \.self) { doc in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Color.ownlyPrimary)
                        .font(.caption)
                    Text(doc)
                        .font(.subheadline)
                }
            }
        }
        .ownlyCard()
    }

    // MARK: - Tax Calculation

    private var taxCalculation: TaxResult {
        let purchaseCents = asset.purchasePriceCents ?? 0
        let buildingValueCents = Int(Double(purchaseCents) * buildingSharePercent / 100.0)
        let maintenanceCents = records.compactMap(\.costCents).reduce(0, +)
        let grossIncome = (Double(annualGrossIncome) ?? 0) * 100 // to cents
        let marginalRate = estimatedMarginalTaxRate(grossIncomeCents: Int(grossIncome), status: filingStatus)

        switch usageType {
        case .rented:
            // AfA: 2% of building value per year (linear, 50 years)
            let afaCents = Int(Double(buildingValueCents) * 0.02)
            // Estimate insurance/management as percentage of maintenance if no specific data
            let insuranceCents = Int(Double(purchaseCents) * 0.003) // ~0.3% of value
            let managementCents = Int(Double(maintenanceCents) * 0.15) // ~15% of maintenance
            let totalDeductions = afaCents + maintenanceCents + insuranceCents + managementCents

            let incomeTaxSavings = Int(Double(totalDeductions) * marginalRate)
            let soliSavings = Int(Double(incomeTaxSavings) * 0.055)
            let churchSavings = churchTax ? Int(Double(incomeTaxSavings) * 0.085) : 0

            return TaxResult(
                afaCents: afaCents,
                maintenanceCents: maintenanceCents,
                insuranceCents: insuranceCents,
                managementCents: managementCents,
                handwerkerCents: 0,
                energeticCents: 0,
                homeOfficeCents: 0,
                totalDeductionsCents: totalDeductions,
                incomeTaxSavingsCents: incomeTaxSavings,
                soliSavingsCents: soliSavings,
                churchTaxSavingsCents: churchSavings,
                totalSavingsCents: incomeTaxSavings + soliSavings + churchSavings
            )

        case .ownerOccupied:
            // §35a Handwerkerleistungen: 20% of labor, max 1200 EUR/year = 120000 cents
            let laborCostsCents = Int(Double(maintenanceCents) * 0.6) // estimate 60% labor
            let handwerkerCents = min(Int(Double(laborCostsCents) * 0.2), 120_000)
            // §35c energetische Sanierung: estimate from upgrade-type maintenance
            let energeticRecords = records.filter { $0.type == .upgrade }
            let energeticCostsCents = energeticRecords.compactMap(\.costCents).reduce(0, +)
            let energeticCents = min(Int(Double(energeticCostsCents) * 0.2), 4_000_000) // max 40k EUR over 3 years
            let totalDeductions = handwerkerCents + energeticCents

            // These are direct tax reductions, not deductions from taxable income
            let soliSavings = Int(Double(totalDeductions) * 0.055)
            let churchSavings = churchTax ? Int(Double(totalDeductions) * 0.085) : 0

            return TaxResult(
                afaCents: 0,
                maintenanceCents: 0,
                insuranceCents: 0,
                managementCents: 0,
                handwerkerCents: handwerkerCents,
                energeticCents: energeticCents,
                homeOfficeCents: 0,
                totalDeductionsCents: totalDeductions,
                incomeTaxSavingsCents: totalDeductions, // direct tax reduction
                soliSavingsCents: soliSavings,
                churchTaxSavingsCents: churchSavings,
                totalSavingsCents: totalDeductions + soliSavings + churchSavings
            )

        case .tenant:
            // Home office: flat 1260 EUR/year = 126000 cents
            let homeOfficeCents = 126_000
            let totalDeductions = homeOfficeCents

            let incomeTaxSavings = Int(Double(totalDeductions) * marginalRate)
            let soliSavings = Int(Double(incomeTaxSavings) * 0.055)
            let churchSavings = churchTax ? Int(Double(incomeTaxSavings) * 0.085) : 0

            return TaxResult(
                afaCents: 0,
                maintenanceCents: 0,
                insuranceCents: 0,
                managementCents: 0,
                handwerkerCents: 0,
                energeticCents: 0,
                homeOfficeCents: homeOfficeCents,
                totalDeductionsCents: totalDeductions,
                incomeTaxSavingsCents: incomeTaxSavings,
                soliSavingsCents: soliSavings,
                churchTaxSavingsCents: churchSavings,
                totalSavingsCents: incomeTaxSavings + soliSavings + churchSavings
            )
        }
    }

    /// Simplified German marginal tax rate estimation
    private func estimatedMarginalTaxRate(grossIncomeCents: Int, status: FilingStatus) -> Double {
        let income = Double(grossIncomeCents) / 100.0
        let effectiveIncome = status == .married ? income / 2.0 : income

        // 2024 German tax brackets (simplified)
        switch effectiveIncome {
        case ..<11_785: return 0.0
        case 11_785..<17_006: return 0.14
        case 17_006..<66_761: return 0.24
        case 66_761..<277_826: return 0.42
        default: return 0.45
        }
    }

    // MARK: - Tips

    private var tipsForUsageType: [String] {
        switch usageType {
        case .rented:
            return [
                String(localized: "tax.tip.rented_1"),
                String(localized: "tax.tip.rented_2"),
                String(localized: "tax.tip.rented_3"),
                String(localized: "tax.tip.rented_4"),
            ]
        case .ownerOccupied:
            return [
                String(localized: "tax.tip.owner_1"),
                String(localized: "tax.tip.owner_2"),
                String(localized: "tax.tip.owner_3"),
            ]
        case .tenant:
            return [
                String(localized: "tax.tip.tenant_1"),
                String(localized: "tax.tip.tenant_2"),
            ]
        }
    }

    private var documentsForUsageType: [String] {
        var docs = [
            String(localized: "tax.doc.purchase_contract"),
            String(localized: "tax.doc.maintenance_invoices"),
            String(localized: "tax.doc.insurance_policy"),
        ]

        switch usageType {
        case .rented:
            docs.append(contentsOf: [
                String(localized: "tax.doc.rental_agreement"),
                String(localized: "tax.doc.management_contract"),
                String(localized: "tax.doc.loan_agreement"),
                String(localized: "tax.doc.depreciation_schedule"),
            ])
        case .ownerOccupied:
            docs.append(contentsOf: [
                String(localized: "tax.doc.craftsman_invoices"),
                String(localized: "tax.doc.energy_certificate"),
            ])
        case .tenant:
            docs.append(contentsOf: [
                String(localized: "tax.doc.rental_contract"),
                String(localized: "tax.doc.utility_bills"),
            ])
        }

        return docs
    }
}

// MARK: - Supporting Types

private enum UsageType: String, CaseIterable, Identifiable {
    case rented
    case ownerOccupied = "owner_occupied"
    case tenant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rented: return String(localized: "tax.usage.rented")
        case .ownerOccupied: return String(localized: "tax.usage.owner_occupied")
        case .tenant: return String(localized: "tax.usage.tenant")
        }
    }
}

private enum FilingStatus: String, CaseIterable, Identifiable {
    case single
    case married

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: return String(localized: "tax.filing.single")
        case .married: return String(localized: "tax.filing.married")
        }
    }
}

private struct TaxResult {
    let afaCents: Int
    let maintenanceCents: Int
    let insuranceCents: Int
    let managementCents: Int
    let handwerkerCents: Int
    let energeticCents: Int
    let homeOfficeCents: Int
    let totalDeductionsCents: Int
    let incomeTaxSavingsCents: Int
    let soliSavingsCents: Int
    let churchTaxSavingsCents: Int
    let totalSavingsCents: Int
}

// MARK: - Subviews

private struct TaxBreakdownRow: View {
    let label: String
    let amount: Int
    let currency: String

    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(settingsStore.formatCurrency(amount, code: currency))
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        }
    }
}

private struct DeductionRow: View {
    let icon: String
    let label: String
    let detail: String
    let amount: Int
    let currency: String

    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.ownlyPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(settingsStore.formatCurrency(amount, code: currency))
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
