import SwiftUI

struct DocumentListView: View {
    let assetId: UUID

    @ObservedObject private var repository = DocumentRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var showingUpload = false
    @State private var groupByCategory = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var documentToDelete: AssetDocument?
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private var documents: [AssetDocument] {
        var list = repository.documentsForAsset(assetId)
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.ocrData?.vendor?.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedDocuments: [(DocumentCategory, [AssetDocument])] {
        let grouped = Dictionary(grouping: documents) { $0.category }
        return DocumentCategory.allCases
            .filter { grouped[$0] != nil }
            .map { ($0, grouped[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if repository.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if documents.isEmpty {
                emptyState
            } else {
                List {
                    if groupByCategory {
                        ForEach(groupedDocuments, id: \.0) { category, docs in
                            Section {
                                ForEach(docs) { doc in
                                    DocumentCardRow(document: doc)
                                }
                                .onDelete { offsets in
                                    confirmDeleteDocuments(offsets, from: docs)
                                }
                            } header: {
                                categoryHeader(category, count: docs.count)
                            }
                        }
                    } else {
                        ForEach(documents) { doc in
                            DocumentCardRow(document: doc)
                        }
                        .onDelete(perform: confirmDeleteFromFlat)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await repository.fetchForAsset(assetId)
                }
            }
        }
        .background(Color.ownlyBackground)
        .searchable(text: $searchText, prompt: String(localized: "search.documents"))
        .navigationTitle(String(localized: "documents.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Group toggle
                    Button {
                        withAnimation { groupByCategory.toggle() }
                    } label: {
                        Image(systemName: groupByCategory
                              ? "rectangle.3.group.fill"
                              : "rectangle.3.group")
                    }

                    // Upload
                    Button {
                        showingUpload = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingUpload) {
            NavigationStack {
                DocumentUploadView(
                    assetId: assetId,
                    onSave: { showingUpload = false }
                )
            }
        }
        .confirmationDialog(
            String(localized: "document.delete_confirm"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) {
                if let doc = documentToDelete {
                    Task {
                        do {
                            try await repository.delete(id: doc.id, assetId: assetId)
                            HapticService.success()
                            toastMessage = String(localized: "document.deleted")
                            showToast = true
                        } catch {
                            HapticService.error()
                            errorMessage = error.localizedDescription
                        }
                        documentToDelete = nil
                    }
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {
                documentToDelete = nil
            }
        } message: {
            if let doc = documentToDelete {
                Text(String(localized: "document.delete_message \(doc.title)"))
            }
        }
        .alert(String(localized: "error"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "ok")) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .toast(isPresented: $showToast, message: toastMessage)
        .onChange(of: showingUpload) { _, isShowing in
            if !isShowing {
                Task { await repository.fetchForAsset(assetId) }
            }
        }
        .onFirstAppear {
            await repository.fetchForAsset(assetId)
        }
    }

    // MARK: - Category Header

    private func categoryHeader(_ category: DocumentCategory, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(category.color)
            Text(category.displayName)
                .font(.subheadline.weight(.semibold))
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
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text(String(localized: "documents.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "documents.empty.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingUpload = true
            } label: {
                Label(String(localized: "documents.upload"), systemImage: "plus.circle.fill")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Delete

    private func confirmDeleteFromFlat(at offsets: IndexSet) {
        guard let firstIndex = offsets.first else { return }
        documentToDelete = documents[firstIndex]
        HapticService.warning()
        showDeleteConfirmation = true
    }

    private func confirmDeleteDocuments(_ offsets: IndexSet, from docs: [AssetDocument]) {
        guard let firstIndex = offsets.first else { return }
        documentToDelete = docs[firstIndex]
        HapticService.warning()
        showDeleteConfirmation = true
    }
}

// MARK: - Document Card Row

struct DocumentCardRow: View {
    let document: AssetDocument
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                document.category.color.opacity(0.12)
                Image(systemName: document.category.icon)
                    .font(.title3)
                    .foregroundStyle(document.category.color)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(document.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                    .lineLimit(1)

                // Category + file type
                HStack(spacing: 6) {
                    Text(document.category.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)

                    if let fileType = document.fileType {
                        Text(fileType.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(fileTypeForeground(fileType))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(fileTypeBackground(fileType))
                            .clipShape(Capsule())
                    }

                    if let size = document.fileSizeFormatted {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(Color.ownlyTextTertiary)
                    }
                }

                // OCR data
                if let ocr = document.ocrData, hasOcrInfo(ocr) {
                    ocrInfoView(ocr)
                }

                // Date
                Text(settingsStore.formatDate(document.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Color.ownlyTextTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.ownlySecondaryBackground)
        .listRowSeparatorTint(Color.ownlySeparator)
    }

    // MARK: - OCR Info

    private func hasOcrInfo(_ ocr: OcrData) -> Bool {
        ocr.amountCents != nil || ocr.vendor != nil || ocr.date != nil
    }

    private func ocrInfoView(_ ocr: OcrData) -> some View {
        HStack(spacing: 8) {
            if let vendor = ocr.vendor, !vendor.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "building.2")
                        .font(.system(size: 8))
                    Text(vendor)
                        .lineLimit(1)
                }
            }

            if let amount = ocr.amountCents {
                HStack(spacing: 2) {
                    Image(systemName: "banknote")
                        .font(.system(size: 8))
                    Text(settingsStore.formatCurrency(amount))
                }
            }

            if let date = ocr.date, !date.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                        .font(.system(size: 8))
                    Text(date)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(Color.ownlyInfo)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.ownlyInfo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - File Type Styling

    private func fileTypeForeground(_ type: String) -> Color {
        switch type.lowercased() {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic": return .green
        case "doc", "docx": return .blue
        default: return Color.ownlyTextSecondary
        }
    }

    private func fileTypeBackground(_ type: String) -> Color {
        fileTypeForeground(type).opacity(0.12)
    }
}

// MARK: - Document Upload View

struct DocumentUploadView: View {
    let assetId: UUID
    let onSave: () -> Void

    @ObservedObject private var repository = DocumentRepository.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category: DocumentCategory = .other
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            // File selection placeholder
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.ownlyPrimary)

                    Text(String(localized: "documents.select_file"))
                        .font(.subheadline)
                        .foregroundStyle(Color.ownlyTextSecondary)

                    Text(String(localized: "documents.supported_formats"))
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            // Details
            Section(String(localized: "documents.details")) {
                TextField(String(localized: "field.title"), text: $title)

                Picker(String(localized: "documents.category"), selection: $category) {
                    ForEach(DocumentCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon)
                            .tag(cat)
                    }
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
                        Text(String(localized: "documents.upload"))
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
        .navigationTitle(String(localized: "documents.upload_title"))
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

        let document = AssetDocument(
            id: UUID(),
            assetId: assetId,
            deviceId: nil,
            userId: userId,
            category: category,
            title: title.trimmingCharacters(in: .whitespaces),
            fileUrl: "", // Would be set after actual upload
            fileType: nil,
            fileSizeBytes: nil,
            ocrData: nil,
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try await repository.create(document)
            HapticService.success()
            onSave()
            dismiss()
        } catch {
            HapticService.error()
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
