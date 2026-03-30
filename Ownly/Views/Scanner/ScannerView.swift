import SwiftUI
import PhotosUI

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var assetRepo = AssetRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var appState: AppState

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var documentTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator

                ScrollView {
                    VStack(spacing: 20) {
                        switch viewModel.step {
                        case .selectMode:
                            modeSelectionStep
                        case .capture:
                            captureStep
                        case .processing:
                            processingStep
                        case .results:
                            resultsStep
                        case .assignToAsset:
                            assignStep
                        }
                    }
                    .padding()
                }
            }
            .background(Color.ownlyBackground)
            .navigationTitle(String(localized: "scanner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.step != .selectMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "scanner.reset")) {
                            withAnimation { viewModel.reset() }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPickerView { image in
                    Task { await viewModel.processImage(image) }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.processImage(image)
                    }
                    selectedPhotoItem = nil
                }
            }
            .onFirstAppear {
                await assetRepo.fetchAll()
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, label in
                VStack(spacing: 4) {
                    Circle()
                        .fill(stepIndex >= index ? Color.ownlyPrimary : Color.ownlyFill)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(stepIndex >= index ? Color.ownlyPrimary : Color.ownlyTextTertiary)
                }
                .frame(maxWidth: .infinity)

                if index < stepLabels.count - 1 {
                    Rectangle()
                        .fill(stepIndex > index ? Color.ownlyPrimary : Color.ownlyFill)
                        .frame(height: 2)
                        .offset(y: -6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.ownlySecondaryBackground)
    }

    private var stepLabels: [String] {
        [
            String(localized: "scanner.step.mode"),
            String(localized: "scanner.step.capture"),
            String(localized: "scanner.step.process"),
            String(localized: "scanner.step.results"),
            String(localized: "scanner.step.assign"),
        ]
    }

    private var stepIndex: Int {
        switch viewModel.step {
        case .selectMode: return 0
        case .capture: return 1
        case .processing: return 2
        case .results: return 3
        case .assignToAsset: return 4
        }
    }

    // MARK: - Step 1: Mode Selection

    private var modeSelectionStep: some View {
        VStack(spacing: 16) {
            Text(String(localized: "scanner.select_mode"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "scanner.select_mode.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)

            ForEach(ScannerViewModel.ScanMode.allCases) { mode in
                ScanModeCard(mode: mode) {
                    withAnimation { viewModel.selectMode(mode) }
                }
            }
        }
    }

    // MARK: - Step 2: Capture

    private var captureStep: some View {
        VStack(spacing: 20) {
            // Mode badge
            HStack(spacing: 6) {
                Image(systemName: viewModel.mode.icon)
                    .font(.caption)
                Text(viewModel.mode.displayName)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.ownlyPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.ownlyPrimary.opacity(0.1))
            .clipShape(Capsule())

            if let image = viewModel.capturedImage {
                // Preview of captured image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            } else {
                // Capture prompt
                VStack(spacing: 24) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.ownlyPrimary.opacity(0.6))

                    Text(String(localized: "scanner.capture.prompt"))
                        .font(.subheadline)
                        .foregroundStyle(Color.ownlyTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .background(Color.ownlySecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Capture actions
            HStack(spacing: 16) {
                Button {
                    showingCamera = true
                } label: {
                    Label(String(localized: "scanner.take_photo"), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ownlyPrimary)

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label(String(localized: "scanner.gallery"), systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(Color.ownlyPrimary)
            }

            if let error = viewModel.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(Color.ownlyError)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ownlyError.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Step 3: Processing

    private var processingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Scanning animation
            ZStack {
                Circle()
                    .fill(Color.ownlyPrimary.opacity(0.08))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(Color.ownlyPrimary.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.ownlyPrimary)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text(String(localized: "scanner.processing"))
                    .font(.title3.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)

                Text(String(localized: "scanner.processing.description"))
                    .font(.subheadline)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .controlSize(.large)
                .tint(Color.ownlyPrimary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 4: Results

    private var resultsStep: some View {
        VStack(spacing: 16) {
            // Confidence score
            confidenceCard

            // Parsed results based on mode
            switch viewModel.mode {
            case .invoice:
                invoiceResultCard
            case .document:
                documentResultCard
            case .nameplate:
                nameplateResultCard
            }

            // Raw text (collapsible)
            rawTextCard

            // Continue button
            Button {
                withAnimation { viewModel.step = .assignToAsset }
            } label: {
                Label(String(localized: "scanner.assign_to_asset"), systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
        }
    }

    // MARK: - Confidence Card

    private var confidenceCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.ownlyFill, lineWidth: 6)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.confidence))
                    .stroke(confidenceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(viewModel.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(confidenceColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "scanner.confidence"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)

                Text(confidenceLabel)
                    .font(.caption)
                    .foregroundStyle(confidenceColor)
            }

            Spacer()

            Image(systemName: confidenceIcon)
                .font(.title2)
                .foregroundStyle(confidenceColor)
        }
        .ownlyCard()
    }

    private var confidenceColor: Color {
        if viewModel.confidence > 0.8 { return .ownlySuccess }
        if viewModel.confidence > 0.6 { return .ownlyWarning }
        return .ownlyError
    }

    private var confidenceLabel: String {
        if viewModel.confidence > 0.8 { return String(localized: "scanner.confidence.high") }
        if viewModel.confidence > 0.6 { return String(localized: "scanner.confidence.medium") }
        return String(localized: "scanner.confidence.low")
    }

    private var confidenceIcon: String {
        if viewModel.confidence > 0.8 { return "checkmark.seal.fill" }
        if viewModel.confidence > 0.6 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    // MARK: - Invoice Result Card

    private var invoiceResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color.ownlyInfo)
                Text(String(localized: "scanner.invoice_data"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
            }

            VStack(spacing: 0) {
                if let amount = viewModel.invoiceData?.amountCents {
                    InvoiceResultRow(
                        icon: "banknote",
                        label: String(localized: "scanner.amount"),
                        value: settingsStore.formatCurrency(amount),
                        valueColor: Color.ownlyPrimary
                    )
                }

                if let date = viewModel.invoiceData?.date, !date.isEmpty {
                    InvoiceResultRow(
                        icon: "calendar",
                        label: String(localized: "scanner.date"),
                        value: date
                    )
                }

                if let vendor = viewModel.invoiceData?.vendor, !vendor.isEmpty {
                    InvoiceResultRow(
                        icon: "building.2",
                        label: String(localized: "scanner.vendor"),
                        value: vendor
                    )
                }

                if let invoiceNr = viewModel.invoiceData?.invoiceNumber, !invoiceNr.isEmpty {
                    InvoiceResultRow(
                        icon: "number",
                        label: String(localized: "scanner.invoice_number"),
                        value: invoiceNr
                    )
                }
            }

            if viewModel.invoiceData?.amountCents == nil
                && viewModel.invoiceData?.date == nil
                && viewModel.invoiceData?.vendor == nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(String(localized: "scanner.no_data_found"))
                        .font(.caption)
                }
                .foregroundStyle(Color.ownlyWarning)
                .padding(8)
            }
        }
        .ownlyCard()
    }

    // MARK: - Document Result Card

    private var documentResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(Color.ownlyInfo)
                Text(String(localized: "scanner.document_data"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
            }

            HStack(spacing: 12) {
                ZStack {
                    viewModel.suggestedCategory.color.opacity(0.12)
                    Image(systemName: viewModel.suggestedCategory.icon)
                        .font(.title2)
                        .foregroundStyle(viewModel.suggestedCategory.color)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "scanner.suggested_category"))
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)
                    Text(viewModel.suggestedCategory.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.ownlyTextPrimary)
                }

                Spacer()
            }
        }
        .ownlyCard()
    }

    // MARK: - Nameplate Result Card

    private var nameplateResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Color.purple)
                Text(String(localized: "scanner.nameplate_data"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
            }

            VStack(spacing: 0) {
                if let manufacturer = viewModel.nameplateData?.manufacturer, !manufacturer.isEmpty {
                    InvoiceResultRow(
                        icon: "building.2",
                        label: String(localized: "scanner.manufacturer"),
                        value: manufacturer
                    )
                }

                if let model = viewModel.nameplateData?.model, !model.isEmpty {
                    InvoiceResultRow(
                        icon: "cube",
                        label: String(localized: "scanner.model"),
                        value: model
                    )
                }

                if let serial = viewModel.nameplateData?.serialNumber, !serial.isEmpty {
                    InvoiceResultRow(
                        icon: "barcode",
                        label: String(localized: "scanner.serial_number"),
                        value: serial
                    )
                }

                if let year = viewModel.nameplateData?.yearOfManufacture {
                    InvoiceResultRow(
                        icon: "calendar",
                        label: String(localized: "scanner.year"),
                        value: "\(year)"
                    )
                }
            }

            if viewModel.nameplateData?.manufacturer == nil
                && viewModel.nameplateData?.model == nil
                && viewModel.nameplateData?.serialNumber == nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(String(localized: "scanner.no_data_found"))
                        .font(.caption)
                }
                .foregroundStyle(Color.ownlyWarning)
                .padding(8)
            }
        }
        .ownlyCard()
    }

    // MARK: - Raw Text Card

    @State private var showingRawText = false

    private var rawTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showingRawText.toggle() }
            } label: {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(Color.ownlyTextSecondary)
                    Text(String(localized: "scanner.raw_text"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.ownlyTextPrimary)
                    Spacer()
                    Image(systemName: showingRawText ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextTertiary)
                }
            }
            .buttonStyle(.plain)

            if showingRawText {
                Text(viewModel.rawText)
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ownlyTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .ownlyCard()
    }

    // MARK: - Step 5: Assign to Asset

    private var assignStep: some View {
        VStack(spacing: 16) {
            Text(String(localized: "scanner.assign.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "scanner.assign.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)

            // Document title
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "scanner.document_title"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ownlyTextSecondary)

                TextField(String(localized: "scanner.document_title.placeholder"), text: $documentTitle)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, 8)

            // Asset picker
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "scanner.select_asset"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ownlyTextSecondary)

                if assetRepo.assets.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.ownlyWarning)
                        Text(String(localized: "scanner.no_assets"))
                            .font(.subheadline)
                            .foregroundStyle(Color.ownlyTextSecondary)
                    }
                    .ownlyCard()
                } else {
                    ForEach(assetRepo.assets) { asset in
                        AssetPickerRow(
                            asset: asset,
                            isSelected: viewModel.selectedAssetId == asset.id
                        ) {
                            withAnimation { viewModel.selectedAssetId = asset.id }
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            // Save button
            Button {
                Task { await saveDocument() }
            } label: {
                Label(String(localized: "scanner.save"), systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
            .disabled(viewModel.selectedAssetId == nil || documentTitle.trimmingCharacters(in: .whitespaces).isEmpty)

            if let error = viewModel.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(Color.ownlyError)
            }
        }
    }

    // MARK: - Actions

    private func saveDocument() async {
        guard let assetId = viewModel.selectedAssetId,
              let userId = appState.currentUserId.flatMap({ UUID(uuidString: $0) }) else { return }

        let title = documentTitle.trimmingCharacters(in: .whitespaces)
        let success = await viewModel.saveAsDocument(
            assetId: assetId,
            userId: userId,
            title: title
        )

        if success {
            subscriptionStore.ocrScansUsed += 1
            withAnimation { viewModel.reset() }
            documentTitle = ""
        }
    }
}

// MARK: - Scan Mode Card

struct ScanModeCard: View {
    let mode: ScannerViewModel.ScanMode
    let action: () -> Void

    private var modeDescription: String {
        switch mode {
        case .invoice: return String(localized: "scanner.mode.invoice.description")
        case .document: return String(localized: "scanner.mode.document.description")
        case .nameplate: return String(localized: "scanner.mode.nameplate.description")
        }
    }

    private var modeColor: Color {
        switch mode {
        case .invoice: return .blue
        case .document: return .teal
        case .nameplate: return .purple
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    modeColor.opacity(0.12)
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundStyle(modeColor)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.ownlyTextPrimary)
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(Color.ownlyTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextTertiary)
            }
            .ownlyCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invoice Result Row

struct InvoiceResultRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .ownlyTextPrimary

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .frame(width: 16)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.ownlyTextSecondary)
            }
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Asset Picker Row

struct AssetPickerRow: View {
    let asset: Asset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    asset.assetType.color.opacity(0.12)
                    Image(systemName: asset.assetType.icon)
                        .font(.body)
                        .foregroundStyle(asset.assetType.color)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ownlyTextPrimary)
                        .lineLimit(1)
                    if let subtitle = asset.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.ownlyTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.ownlyPrimary : Color.ownlyTextTertiary)
            }
            .padding(12)
            .background(isSelected ? Color.ownlyPrimary.opacity(0.06) : Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.ownlyPrimary.opacity(0.3) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
