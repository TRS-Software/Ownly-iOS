import SwiftUI
import PDFKit

struct ExportView: View {
    let asset: Asset

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var exportFormat: ExportFormat = .pdf
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var pdfData: Data?
    @State private var exportData: ExportService.ExportData?
    @State private var error: String?
    @State private var showingError = false

    private let exportService = ExportService.shared
    private let deviceRepo = DeviceRepository.shared
    private let maintenanceRepo = MaintenanceRepository.shared
    private let documentRepo = DocumentRepository.shared
    private let mediaRepo = MediaRepository.shared
    private let timelineRepo = TimelineRepository.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    previewCard
                    formatPicker
                    if exportFormat == .pdf {
                        pdfPreviewSection
                    }
                    exportButton
                    Spacer(minLength: 40)
                }
            }
            .padding()
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "export.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "error.title"), isPresented: $showingError) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(error ?? "")
        }
        .onFirstAppear {
            await loadData()
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "export.preview"), systemImage: "doc.richtext.fill")
                .font(.headline)

            HStack(spacing: 14) {
                Image(systemName: asset.assetType.icon)
                    .font(.title)
                    .foregroundStyle(asset.assetType.color)
                    .frame(width: 48, height: 48)
                    .background(asset.assetType.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.subheadline.bold())
                    Text(asset.assetType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            let passTitle = asset.assetType.isProperty
                ? String(localized: "export.digital_house_pass")
                : String(localized: "export.digital_asset_pass")

            Text(passTitle)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ownlyPrimary)

            if let data = exportData {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ExportCountItem(
                        icon: "cpu.fill",
                        label: String(localized: "export.devices"),
                        count: data.devices.count
                    )
                    ExportCountItem(
                        icon: "wrench.fill",
                        label: String(localized: "export.maintenance"),
                        count: data.maintenance.count
                    )
                    ExportCountItem(
                        icon: "doc.fill",
                        label: String(localized: "export.documents"),
                        count: data.documents.count
                    )
                    ExportCountItem(
                        icon: "photo.fill",
                        label: String(localized: "export.photos"),
                        count: data.media.count
                    )
                }
            }
        }
        .ownlyCard()
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "export.format"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker(String(localized: "export.format"), selection: $exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Label(format.displayName, systemImage: format.icon)
                        .tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
        .ownlyCard()
    }

    // MARK: - PDF Preview

    @ViewBuilder
    private var pdfPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "export.pdf_preview"), systemImage: "eye.fill")
                .font(.headline)

            if let pdfData, let document = PDFDocument(data: pdfData) {
                PDFPreviewView(document: document)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.ownlySeparator, lineWidth: 0.5)
                    )
            } else if isGenerating {
                ProgressView(String(localized: "export.generating"))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(String(localized: "export.generate_first"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await generatePDF() }
                    } label: {
                        Label(String(localized: "export.generate_preview"), systemImage: "arrow.clockwise")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.ownlyPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .ownlyCard()
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task { await exportAndShare() }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                }
                Text(isGenerating
                     ? String(localized: "export.generating")
                     : String(localized: "export.share"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.ownlyPrimary)
        .disabled(isGenerating || exportData == nil)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        async let d: () = deviceRepo.fetchForAsset(asset.id)
        async let m: () = maintenanceRepo.fetchForAsset(asset.id)
        async let doc: () = documentRepo.fetchForAsset(asset.id)
        async let med: () = mediaRepo.fetchForAsset(asset.id)
        async let t: () = timelineRepo.fetchForAsset(asset.id)

        _ = await (d, m, doc, med, t)

        exportData = ExportService.ExportData(
            asset: asset,
            devices: deviceRepo.devicesForAsset(asset.id),
            maintenance: maintenanceRepo.recordsForAsset(asset.id),
            documents: documentRepo.documentsForAsset(asset.id),
            media: mediaRepo.mediaForAsset(asset.id),
            timeline: timelineRepo.entriesForAsset(asset.id)
        )

        isLoading = false
    }

    private func generatePDF() async {
        guard let data = exportData else { return }
        isGenerating = true
        pdfData = exportService.generatePDF(from: data)
        isGenerating = false
    }

    private func exportAndShare() async {
        guard let data = exportData else { return }
        isGenerating = true

        switch exportFormat {
        case .pdf:
            if pdfData == nil {
                pdfData = exportService.generatePDF(from: data)
            }
            guard let pdf = pdfData else {
                isGenerating = false
                return
            }
            shareFile(data: pdf, fileName: "\(asset.name)_Passport.pdf")

        case .zip:
            // For ZIP, generate PDF and bundle it
            let pdf = exportService.generatePDF(from: data)
            shareFile(data: pdf, fileName: "\(asset.name)_Passport.pdf")
        }

        isGenerating = false
    }

    private func shareFile(data: Data, fileName: String) {
        let sanitizedName = fileName.replacingOccurrences(of: "/", with: "_")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizedName)
        do {
            try data.write(to: tempURL)
        } catch {
            self.error = error.localizedDescription
            showingError = true
            return
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.maxY - 100,
                width: 0, height: 0
            )
        }

        rootVC.present(activityVC, animated: true)
    }
}

// MARK: - Supporting Types

private enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case zip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .zip: return "ZIP"
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .zip: return "doc.zipper"
        }
    }
}

// MARK: - Subviews

private struct ExportCountItem: View {
    let icon: String
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.ownlyPrimary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(Color.ownlyTextPrimary)
        }
    }
}

private struct PDFPreviewView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
