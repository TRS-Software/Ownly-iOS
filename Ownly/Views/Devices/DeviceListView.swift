import SwiftUI

struct DeviceListView: View {
    let assetId: UUID
    let assetType: AssetType

    @ObservedObject private var repository = DeviceRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var appState: AppState

    @State private var showingAddDevice = false
    @State private var searchText = ""
    @State private var selectedCategory: DeviceCategory?
    @State private var errorMessage: String?

    private var devices: [Device] {
        var list = repository.devicesForAsset(assetId)
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.manufacturer?.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.model?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: String(localized: "filter.all"),
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(assetType.deviceCategories, id: \.self) { category in
                        FilterChip(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if repository.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if devices.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(devices) { device in
                        NavigationLink(value: device) {
                            DeviceRow(device: device)
                        }
                        .listRowBackground(Color.ownlySecondaryBackground)
                        .listRowSeparatorTint(Color.ownlySeparator)
                    }
                    .onDelete(perform: deleteDevices)
                }
                .listStyle(.plain)
                .refreshable {
                    await repository.fetchForAsset(assetId)
                }
            }
        }
        .background(Color.ownlyBackground)
        .searchable(text: $searchText, prompt: String(localized: "search.devices"))
        .navigationTitle(String(localized: "devices.title"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Device.self) { device in
            DeviceDetailView(device: device, assetType: assetType)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddDevice = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            NavigationStack {
                DeviceFormView(
                    assetId: assetId,
                    assetType: assetType,
                    onSave: { showingAddDevice = false }
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text(String(localized: "devices.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "devices.empty.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddDevice = true
            } label: {
                Label(String(localized: "devices.add"), systemImage: "plus.circle.fill")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Delete

    private func deleteDevices(at offsets: IndexSet) {
        let devicesToDelete = offsets.map { devices[$0] }
        for device in devicesToDelete {
            Task {
                do {
                    try await repository.delete(id: device.id, assetId: assetId)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                device.status.color.opacity(0.12)
                Image(systemName: device.category.icon)
                    .font(.title3)
                    .foregroundStyle(device.status.color)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                    .lineLimit(1)

                if let manufacturer = device.manufacturer, let model = device.model {
                    Text("\(manufacturer) \(model)")
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)
                        .lineLimit(1)
                } else if let manufacturer = device.manufacturer {
                    Text(manufacturer)
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)
                        .lineLimit(1)
                }

                // Warranty info
                if device.isWarrantyActive, let days = device.warrantyRemainingDays {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.caption2)
                        Text(String(localized: "device.warranty_days_remaining \(days)"))
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.ownlySuccess)
                } else if device.warrantyUntil != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.slash")
                            .font(.caption2)
                        Text(String(localized: "device.warranty_expired"))
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.ownlyTextTertiary)
                }
            }

            Spacer()

            // Status badge
            HStack(spacing: 4) {
                Image(systemName: device.status.icon)
                    .font(.caption2)
                Text(device.status.displayName)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(device.status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(device.status.color.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    let device: Device
    let assetType: AssetType

    @ObservedObject private var maintenanceRepo = MaintenanceRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingEdit = false

    private var maintenanceEvents: [MaintenanceRecord] {
        maintenanceRepo.recordsForAsset(device.assetId)
            .filter { $0.deviceId == device.id }
            .sorted { $0.performedAt < $1.performedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                headerCard

                // Warranty progress
                if device.warrantyUntil != nil {
                    warrantySection
                }

                // Lifetime progress
                if device.lifetimeProgressPercent != nil {
                    lifetimeSection
                }

                // Metadata
                metadataSection

                // Lifecycle timeline
                lifecycleTimeline
            }
            .padding()
        }
        .background(Color.ownlyBackground)
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                DeviceFormView(
                    assetId: device.assetId,
                    assetType: assetType,
                    editing: device,
                    onSave: { showingEdit = false }
                )
            }
        }
        .onFirstAppear {
            await maintenanceRepo.fetchForAsset(device.assetId)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                device.status.color.opacity(0.12)
                Image(systemName: device.category.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(device.status.color)
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 4) {
                Text(device.name)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)

                Text(device.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.ownlyTextSecondary)
            }

            // Status badge
            HStack(spacing: 6) {
                Image(systemName: device.status.icon)
                    .font(.caption)
                Text(device.status.displayName)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(device.status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(device.status.color.opacity(0.12))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .ownlyCard()
    }

    // MARK: - Warranty

    private var warrantySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(device.isWarrantyActive ? Color.ownlySuccess : Color.ownlyTextTertiary)
                Text(String(localized: "device.warranty"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                Spacer()
                if device.isWarrantyActive {
                    Text(String(localized: "device.active"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ownlySuccess)
                } else {
                    Text(String(localized: "device.expired"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ownlyError)
                }
            }

            if let warrantyUntil = device.warrantyUntil {
                // Progress bar
                warrantyProgressBar

                HStack {
                    if let installDate = device.installationDate {
                        Text(settingsStore.formatDate(installDate))
                            .font(.caption2)
                            .foregroundStyle(Color.ownlyTextTertiary)
                    }
                    Spacer()
                    Text(settingsStore.formatDate(warrantyUntil))
                        .font(.caption2)
                        .foregroundStyle(Color.ownlyTextTertiary)
                }

                if let days = device.warrantyRemainingDays, device.isWarrantyActive {
                    Text(String(localized: "device.warranty_days_remaining \(days)"))
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)
                }
            }
        }
        .ownlyCard()
    }

    private var warrantyProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ownlyFill)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(device.isWarrantyActive ? Color.ownlySuccess : Color.ownlyError)
                    .frame(width: geometry.size.width * warrantyProgress, height: 8)
            }
        }
        .frame(height: 8)
    }

    private var warrantyProgress: Double {
        guard let start = device.installationDate, let end = device.warrantyUntil else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1.0)
    }

    // MARK: - Lifetime

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "hourglass")
                    .foregroundStyle(Color.ownlyPrimary)
                Text(String(localized: "device.expected_lifetime"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                Spacer()
                if let years = device.expectedLifetimeYears {
                    Text(String(localized: "device.years \(years)"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ownlyTextSecondary)
                }
            }

            if let progress = device.lifetimeProgressPercent {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.ownlyFill)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(lifetimeColor(progress))
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    if let installDate = device.installationDate {
                        Text(settingsStore.formatDate(installDate))
                            .font(.caption2)
                            .foregroundStyle(Color.ownlyTextTertiary)
                    }
                    Spacer()
                    if let eol = device.expectedEndOfLife {
                        Text(settingsStore.formatDate(eol))
                            .font(.caption2)
                            .foregroundStyle(Color.ownlyTextTertiary)
                    }
                }

                Text(String(localized: "device.lifetime_used \((progress * 100).formattedPercent(decimals: 0))"))
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
            }
        }
        .ownlyCard()
    }

    private func lifetimeColor(_ progress: Double) -> Color {
        if progress < 0.5 { return .ownlySuccess }
        if progress < 0.8 { return .ownlyWarning }
        return .ownlyError
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "device.details"))
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            VStack(spacing: 0) {
                if let manufacturer = device.manufacturer {
                    MetadataRow(label: String(localized: "device.manufacturer"), value: manufacturer)
                }
                if let model = device.model {
                    MetadataRow(label: String(localized: "device.model"), value: model)
                }
                if let serial = device.serialNumber {
                    MetadataRow(label: String(localized: "device.serial_number"), value: serial)
                }
                if let installDate = device.installationDate {
                    MetadataRow(label: String(localized: "device.installation_date"), value: settingsStore.formatDate(installDate))
                }
                MetadataRow(label: String(localized: "device.category"), value: device.category.displayName)
            }
        }
        .ownlyCard()
    }

    // MARK: - Lifecycle Timeline

    private var lifecycleTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "device.lifecycle"))
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            let events = buildLifecycleEvents()

            if events.isEmpty {
                Text(String(localized: "device.no_events"))
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .top, spacing: 14) {
                            // Timeline visual
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(event.color)
                                    .frame(width: 12, height: 12)

                                if index < events.count - 1 {
                                    Rectangle()
                                        .fill(Color.ownlySeparator)
                                        .frame(width: 2)
                                        .frame(minHeight: 40)
                                }
                            }
                            .frame(width: 12)

                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: event.icon)
                                        .font(.caption)
                                        .foregroundStyle(event.color)
                                    Text(event.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.ownlyTextPrimary)
                                }

                                Text(settingsStore.formatDate(event.date))
                                    .font(.caption)
                                    .foregroundStyle(Color.ownlyTextTertiary)

                                if let subtitle = event.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.ownlyTextSecondary)
                                }

                                if let cost = event.costCents {
                                    Text(settingsStore.formatCurrency(cost))
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.ownlyPrimary)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
        .ownlyCard()
    }

    private struct LifecycleEvent {
        let title: String
        let date: Date
        let subtitle: String?
        let costCents: Int?
        let icon: String
        let color: Color
    }

    private func buildLifecycleEvents() -> [LifecycleEvent] {
        var events: [LifecycleEvent] = []

        // Installation
        if let installDate = device.installationDate {
            events.append(LifecycleEvent(
                title: String(localized: "device.event.installed"),
                date: installDate,
                subtitle: device.manufacturer.map { "\($0) \(device.model ?? "")" },
                costCents: nil,
                icon: "arrow.down.to.line",
                color: .ownlySuccess
            ))
        }

        // Warranty start
        if let installDate = device.installationDate, device.warrantyUntil != nil {
            events.append(LifecycleEvent(
                title: String(localized: "device.event.warranty_started"),
                date: installDate,
                subtitle: nil,
                costCents: nil,
                icon: "shield.checkered",
                color: .ownlyInfo
            ))
        }

        // Maintenance events
        for record in maintenanceEvents {
            events.append(LifecycleEvent(
                title: record.title,
                date: record.performedAt,
                subtitle: record.performedBy,
                costCents: record.costCents,
                icon: record.type.icon,
                color: record.type.color
            ))
        }

        // Warranty end
        if let warrantyEnd = device.warrantyUntil, warrantyEnd <= Date() {
            events.append(LifecycleEvent(
                title: String(localized: "device.event.warranty_expired"),
                date: warrantyEnd,
                subtitle: nil,
                costCents: nil,
                icon: "shield.slash",
                color: .ownlyWarning
            ))
        }

        // Expected end of life
        if let eol = device.expectedEndOfLife {
            events.append(LifecycleEvent(
                title: String(localized: "device.event.expected_eol"),
                date: eol,
                subtitle: nil,
                costCents: nil,
                icon: "clock.badge.exclamationmark",
                color: eol <= Date() ? .ownlyError : .ownlyTextTertiary
            ))
        }

        return events.sorted { $0.date < $1.date }
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.ownlyTextSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.ownlyTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Device Form View

struct DeviceFormView: View {
    let assetId: UUID
    let assetType: AssetType
    var editing: Device?
    let onSave: () -> Void

    @ObservedObject private var repository = DeviceRepository.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: DeviceCategory = .other
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serialNumber = ""
    @State private var installationDate = Date()
    @State private var hasInstallationDate = false
    @State private var warrantyUntil = Date()
    @State private var hasWarranty = false
    @State private var expectedLifetimeYears = ""
    @State private var status: DeviceStatus = .active
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isEditing: Bool { editing != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            // Basic info
            Section(String(localized: "device.basic_info")) {
                TextField(String(localized: "field.name"), text: $name)

                Picker(String(localized: "device.category"), selection: $category) {
                    ForEach(assetType.deviceCategories, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon)
                            .tag(cat)
                    }
                }

                Picker(String(localized: "device.status"), selection: $status) {
                    ForEach(DeviceStatus.allCases, id: \.self) { s in
                        Label(s.displayName, systemImage: s.icon)
                            .tag(s)
                    }
                }
            }

            // Manufacturer details
            Section(String(localized: "device.manufacturer_info")) {
                TextField(String(localized: "device.manufacturer"), text: $manufacturer)
                TextField(String(localized: "device.model"), text: $model)
                TextField(String(localized: "device.serial_number"), text: $serialNumber)
            }

            // Installation
            Section(String(localized: "device.installation")) {
                Toggle(String(localized: "device.has_installation_date"), isOn: $hasInstallationDate)
                if hasInstallationDate {
                    DatePicker(
                        String(localized: "device.installation_date"),
                        selection: $installationDate,
                        displayedComponents: .date
                    )
                }
            }

            // Warranty
            Section(String(localized: "device.warranty")) {
                Toggle(String(localized: "device.has_warranty"), isOn: $hasWarranty)
                if hasWarranty {
                    DatePicker(
                        String(localized: "device.warranty_until"),
                        selection: $warrantyUntil,
                        displayedComponents: .date
                    )
                }
            }

            // Lifetime
            Section(String(localized: "device.expected_lifetime")) {
                TextField(
                    String(localized: "device.lifetime_years"),
                    text: $expectedLifetimeYears
                )
                .keyboardType(.numberPad)
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
                        Text(isEditing ? String(localized: "save") : String(localized: "devices.add"))
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
        .navigationTitle(isEditing ? String(localized: "device.edit") : String(localized: "device.new"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel")) { dismiss() }
            }
        }
        .onAppear {
            if let device = editing {
                name = device.name
                category = device.category
                manufacturer = device.manufacturer ?? ""
                model = device.model ?? ""
                serialNumber = device.serialNumber ?? ""
                status = device.status
                if let date = device.installationDate {
                    installationDate = date
                    hasInstallationDate = true
                }
                if let date = device.warrantyUntil {
                    warrantyUntil = date
                    hasWarranty = true
                }
                if let years = device.expectedLifetimeYears {
                    expectedLifetimeYears = "\(years)"
                }
            } else {
                // Default to first available category
                category = assetType.deviceCategories.first ?? .other
            }
        }
    }

    private func submit() async {
        guard let userId = appState.currentUserId.flatMap({ UUID(uuidString: $0) }) else { return }
        isSubmitting = true
        errorMessage = nil

        let device = Device(
            id: editing?.id ?? UUID(),
            assetId: assetId,
            userId: userId,
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            model: model.isEmpty ? nil : model,
            serialNumber: serialNumber.isEmpty ? nil : serialNumber,
            installationDate: hasInstallationDate ? installationDate : nil,
            warrantyUntil: hasWarranty ? warrantyUntil : nil,
            expectedLifetimeYears: Int(expectedLifetimeYears),
            metadata: editing?.metadata ?? [:],
            manualUrl: editing?.manualUrl,
            status: status,
            createdAt: editing?.createdAt ?? Date(),
            updatedAt: Date()
        )

        do {
            if isEditing {
                try await repository.update(device)
            } else {
                try await repository.create(device)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
