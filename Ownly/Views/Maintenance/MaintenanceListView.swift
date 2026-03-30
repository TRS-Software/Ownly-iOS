import SwiftUI

struct MaintenanceListView: View {
    let assetId: UUID
    let currency: String

    @ObservedObject private var repository = MaintenanceRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var showingAddMaintenance = false
    @State private var selectedTypeFilter: MaintenanceType?
    @State private var errorMessage: String?

    private var records: [MaintenanceRecord] {
        var list = repository.recordsForAsset(assetId)
        if let filter = selectedTypeFilter {
            list = list.filter { $0.type == filter }
        }
        return list.sorted { $0.performedAt > $1.performedAt }
    }

    private var totalCost: Int {
        records.compactMap(\.costCents).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: String(localized: "filter.all"),
                        isSelected: selectedTypeFilter == nil
                    ) {
                        selectedTypeFilter = nil
                    }

                    ForEach(MaintenanceType.allCases) { type in
                        FilterChip(
                            title: type.displayName,
                            icon: type.icon,
                            isSelected: selectedTypeFilter == type
                        ) {
                            selectedTypeFilter = selectedTypeFilter == type ? nil : type
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if repository.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Total cost card
                        totalCostCard

                        // Timeline
                        timelineContent
                    }
                    .padding()
                }
                .refreshable {
                    await repository.fetchForAsset(assetId)
                }
            }
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "maintenance.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddMaintenance = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMaintenance) {
            NavigationStack {
                MaintenanceFormView(
                    assetId: assetId,
                    currency: currency,
                    onSave: { showingAddMaintenance = false }
                )
            }
        }
        .alert(String(localized: "error"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "ok")) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .onFirstAppear {
            await repository.fetchForAsset(assetId)
        }
    }

    // MARK: - Total Cost Card

    private var totalCostCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "maintenance.total_cost"))
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                Text(settingsStore.formatCurrency(totalCost, code: currency))
                    .font(.title2.bold())
                    .foregroundStyle(Color.ownlyPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(localized: "maintenance.count"))
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                Text("\(records.count)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
            }
        }
        .ownlyCard()
    }

    // MARK: - Timeline

    private var timelineContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                HStack(alignment: .top, spacing: 16) {
                    // Vertical timeline
                    VStack(spacing: 0) {
                        // Dot
                        Circle()
                            .fill(record.type.color)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .fill(Color.ownlyBackground)
                                    .frame(width: 6, height: 6)
                            }

                        // Connecting line
                        if index < records.count - 1 {
                            Rectangle()
                                .fill(Color.ownlySeparator)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 14)

                    // Card content
                    MaintenanceTimelineCard(
                        record: record,
                        currency: currency,
                        onDelete: {
                            deleteRecord(record)
                        }
                    )
                    .padding(.bottom, index < records.count - 1 ? 8 : 0)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text(String(localized: "maintenance.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "maintenance.empty.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddMaintenance = true
            } label: {
                Label(String(localized: "maintenance.add"), systemImage: "plus.circle.fill")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Delete

    private func deleteRecord(_ record: MaintenanceRecord) {
        Task {
            do {
                try await repository.delete(id: record.id, assetId: assetId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Timeline Card

struct MaintenanceTimelineCard: View {
    let record: MaintenanceRecord
    let currency: String
    let onDelete: () -> Void

    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: type badge + date
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: record.type.icon)
                        .font(.caption2)
                    Text(record.type.displayName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(record.type.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(record.type.color.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                Text(settingsStore.formatDate(record.performedAt))
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextTertiary)
            }

            // Title
            Text(record.title)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyTextPrimary)
                .lineLimit(2)

            // Description
            if let description = record.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .lineLimit(3)
            }

            // Footer: cost + performed by
            HStack {
                if let cost = record.costCents {
                    Text(settingsStore.formatCurrency(cost, code: currency))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.ownlyPrimary)
                }

                Spacer()

                if let performedBy = record.performedBy, !performedBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(performedBy)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.ownlyTextSecondary)
                }
            }

            // Due date warning
            if record.isDue {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(String(localized: "maintenance.overdue"))
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.ownlyError)
            } else if record.isDueSoon, let dueDate = record.nextDueDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(String(localized: "maintenance.due_soon \(settingsStore.formatDate(dueDate))"))
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.ownlyWarning)
            }
        }
        .ownlyCard()
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(String(localized: "delete"), systemImage: "trash")
            }
        }
        .confirmationDialog(
            String(localized: "maintenance.delete_confirm"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Maintenance Form View

struct MaintenanceFormView: View {
    let assetId: UUID
    let currency: String
    let onSave: () -> Void

    @ObservedObject private var repository = MaintenanceRepository.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var type: MaintenanceType = .maintenance
    @State private var title = ""
    @State private var description = ""
    @State private var performedBy = ""
    @State private var performedAt = Date()
    @State private var costText = ""
    @State private var hasNextDueDate = false
    @State private var nextDueDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var costCents: Int? {
        guard !costText.isEmpty else { return nil }
        if let value = Double(costText.replacingOccurrences(of: ",", with: ".")) {
            return Int((value * 100).rounded())
        }
        return nil
    }

    var body: some View {
        Form {
            // Type
            Section(String(localized: "maintenance.type")) {
                Picker(String(localized: "maintenance.type"), selection: $type) {
                    ForEach(MaintenanceType.allCases) { t in
                        Label(t.displayName, systemImage: t.icon)
                            .tag(t)
                    }
                }
                .pickerStyle(.menu)
            }

            // Details
            Section(String(localized: "maintenance.details")) {
                TextField(String(localized: "field.title"), text: $title)

                TextField(String(localized: "field.description"), text: $description, axis: .vertical)
                    .lineLimit(2...6)

                TextField(String(localized: "maintenance.performed_by"), text: $performedBy)
            }

            // Date
            Section(String(localized: "maintenance.date")) {
                DatePicker(
                    String(localized: "maintenance.performed_at"),
                    selection: $performedAt,
                    displayedComponents: .date
                )
            }

            // Cost
            Section(String(localized: "maintenance.cost")) {
                HStack {
                    TextField(String(localized: "maintenance.amount"), text: $costText)
                        .keyboardType(.decimalPad)
                    Text(currency)
                        .foregroundStyle(Color.ownlyTextSecondary)
                }
            }

            // Next due date
            Section(String(localized: "maintenance.next_due")) {
                Toggle(String(localized: "maintenance.schedule_next"), isOn: $hasNextDueDate)
                if hasNextDueDate {
                    DatePicker(
                        String(localized: "maintenance.next_due_date"),
                        selection: $nextDueDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                }
            }

            // Submit
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "maintenance.add"))
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(!isValid || isSubmitting)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(String(localized: "maintenance.new"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel")) { dismiss() }
            }
        }
    }

    private func submit() async {
        guard let userId = appState.currentUserId.flatMap({ UUID(uuidString: $0) }) else { return }
        isSubmitting = true
        errorMessage = nil

        let record = MaintenanceRecord(
            id: UUID(),
            assetId: assetId,
            deviceId: nil,
            userId: userId,
            type: type,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            performedBy: performedBy.isEmpty ? nil : performedBy,
            performedAt: performedAt,
            nextDueDate: hasNextDueDate ? nextDueDate : nil,
            costCents: costCents,
            currency: currency,
            invoiceDocumentId: nil,
            metadata: [:],
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try await repository.create(record)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
