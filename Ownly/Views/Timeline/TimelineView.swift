import SwiftUI

struct TimelineView: View {
    let assetId: UUID

    @ObservedObject private var repository = TimelineRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var selectedTypeFilter: TimelineEntryType?
    @State private var errorMessage: String?

    private var allEntries: [TimelineEntry] {
        repository.entriesForAsset(assetId)
    }

    private var filteredEntries: [TimelineEntry] {
        var list = allEntries
        if let filter = selectedTypeFilter {
            list = list.filter { $0.entryType == filter }
        }
        return list.sorted { $0.occurredAt > $1.occurredAt }
    }

    /// Group entries by month/year
    private var groupedEntries: [(String, [TimelineEntry])] {
        let formatter = DateFormatter()
        formatter.locale = settingsStore.currentLocale
        formatter.dateFormat = "LLLL yyyy"

        let grouped = Dictionary(grouping: filteredEntries) { entry in
            formatter.string(from: entry.occurredAt)
        }

        // Sort groups by most recent first
        return grouped
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.value.first?.occurredAt,
                      let rhsDate = rhs.value.first?.occurredAt else { return false }
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            filterChipsBar

            if repository.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(groupedEntries.enumerated()), id: \.element.0) { groupIndex, group in
                            let (monthYear, entries) = group

                            // Month/Year header
                            monthHeader(monthYear, count: entries.count)
                                .padding(.top, groupIndex == 0 ? 8 : 20)
                                .padding(.bottom, 12)

                            // Timeline entries
                            ForEach(Array(entries.enumerated()), id: \.element.id) { entryIndex, entry in
                                let isLast = entryIndex == entries.count - 1
                                    && groupIndex == groupedEntries.count - 1

                                TimelineRow(
                                    entry: entry,
                                    isLast: isLast
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await repository.fetchForAsset(assetId)
                }
            }
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "timeline.title"))
        .navigationBarTitleDisplayMode(.large)
        .alert(String(localized: "error"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "ok")) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .onFirstAppear {
            await repository.fetchForAsset(assetId)
        }
    }

    // MARK: - Filter Chips

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: String(localized: "filter.all"),
                    isSelected: selectedTypeFilter == nil
                ) {
                    withAnimation { selectedTypeFilter = nil }
                }

                ForEach(activeFilterTypes, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: selectedTypeFilter == type
                    ) {
                        withAnimation {
                            selectedTypeFilter = selectedTypeFilter == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    /// Only show filter chips for entry types that actually exist in the data
    private var activeFilterTypes: [TimelineEntryType] {
        let presentTypes = Set(allEntries.map(\.entryType))
        return TimelineEntryType.allCases.filter { presentTypes.contains($0) }
    }

    // MARK: - Month Header

    private func monthHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.capitalized)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyTextPrimary)
            Spacer()
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(Color.ownlyTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.ownlyFill)
                .clipShape(Capsule())
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text(String(localized: "timeline.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "timeline.empty.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {
    let entry: TimelineEntry
    let isLast: Bool

    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Date column
            dateColumn
                .frame(width: 56)

            // Center: Dot + vertical line
            timelineDot
                .frame(width: 32)

            // Right: Event card
            eventCard
                .padding(.bottom, isLast ? 0 : 12)
        }
    }

    // MARK: - Date Column

    private var dateColumn: some View {
        VStack(spacing: 2) {
            Text(dayString)
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)
            Text(monthShortString)
                .font(.caption2)
                .foregroundStyle(Color.ownlyTextSecondary)
            Text(timeString)
                .font(.system(size: 9))
                .foregroundStyle(Color.ownlyTextTertiary)
        }
        .padding(.top, 2)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = settingsStore.currentLocale
        formatter.dateFormat = "d"
        return formatter.string(from: entry.occurredAt)
    }

    private var monthShortString: String {
        let formatter = DateFormatter()
        formatter.locale = settingsStore.currentLocale
        formatter.dateFormat = "MMM"
        return formatter.string(from: entry.occurredAt)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = settingsStore.currentLocale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.occurredAt)
    }

    // MARK: - Timeline Dot + Line

    private var timelineDot: some View {
        VStack(spacing: 0) {
            // Dot
            ZStack {
                Circle()
                    .fill(entry.entryType.color.opacity(0.2))
                    .frame(width: 24, height: 24)

                Circle()
                    .fill(entry.entryType.color)
                    .frame(width: 12, height: 12)
            }

            // Connecting line
            if !isLast {
                Rectangle()
                    .fill(Color.ownlySeparator)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Event Card

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type badge
            HStack(spacing: 4) {
                Image(systemName: entry.entryType.icon)
                    .font(.caption2)
                Text(entry.entryType.displayName)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(entry.entryType.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(entry.entryType.color.opacity(0.12))
            .clipShape(Capsule())

            // Title
            Text(entry.title)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyTextPrimary)
                .lineLimit(2)

            // Description
            if let description = entry.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .lineLimit(3)
            }

            // Reference type indicator
            if let refType = entry.referenceType, !refType.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: referenceIcon(refType))
                        .font(.system(size: 9))
                    Text(referenceLabel(refType))
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.ownlyTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ownlyCard()
        .ownlyCardShadow()
    }

    private func referenceIcon(_ type: String) -> String {
        switch type {
        case "device": return "cpu"
        case "maintenance": return "wrench.fill"
        case "document": return "doc.fill"
        case "media": return "photo.fill"
        default: return "link"
        }
    }

    private func referenceLabel(_ type: String) -> String {
        switch type {
        case "device": return String(localized: "timeline.ref.device")
        case "maintenance": return String(localized: "timeline.ref.maintenance")
        case "document": return String(localized: "timeline.ref.document")
        case "media": return String(localized: "timeline.ref.media")
        default: return type
        }
    }
}

// MARK: - TimelineEntryType Display Name

extension TimelineEntryType {
    var displayName: String {
        switch self {
        case .assetCreated: return String(localized: "timeline.type.asset_created")
        case .deviceAdded: return String(localized: "timeline.type.device_added")
        case .deviceReplaced: return String(localized: "timeline.type.device_replaced")
        case .maintenance: return String(localized: "timeline.type.maintenance")
        case .repair: return String(localized: "timeline.type.repair")
        case .inspection: return String(localized: "timeline.type.inspection")
        case .documentAdded: return String(localized: "timeline.type.document_added")
        case .photoAdded: return String(localized: "timeline.type.photo_added")
        case .beforeAfter: return String(localized: "timeline.type.before_after")
        case .note: return String(localized: "timeline.type.note")
        case .reminder: return String(localized: "timeline.type.reminder")
        }
    }
}
