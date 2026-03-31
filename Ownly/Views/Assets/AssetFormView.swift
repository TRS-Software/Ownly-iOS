import SwiftUI
import PhotosUI

struct AssetFormView: View {
    @StateObject private var viewModel: AssetFormViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var engagementStore: EngagementStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    init(editing asset: Asset? = nil) {
        _viewModel = StateObject(wrappedValue: AssetFormViewModel(editing: asset))
    }

    var body: some View {
        Group {
            switch viewModel.step {
            case .selectType:
                typeSelectionStep
            case .fillDetails:
                detailsStep
            }
        }
        .navigationTitle(viewModel.editingAsset != nil
                         ? String(localized: "asset.edit")
                         : String(localized: "asset.new"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel")) { dismiss() }
            }
        }
    }

    // MARK: - Step 1: Type Selection

    private var typeSelectionStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(String(localized: "asset.select_type"))
                    .font(.headline)
                    .padding(.top)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(AssetType.allCases) { type in
                        Button {
                            viewModel.selectType(type)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .foregroundStyle(type.color)
                                Text(type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(Color.ownlyTextPrimary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .background(type.color.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(viewModel.assetType == type ? type.color : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        Form {
            // Cover Image
            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let image = viewModel.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(String(localized: "asset.add_cover_photo"))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.ownlySecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            viewModel.coverImage = image
                        }
                    }
                }
            }

            // Name & Description
            Section(String(localized: "asset.basic_info")) {
                TextField(String(localized: "field.name"), text: $viewModel.name)
                TextField(String(localized: "field.description"), text: $viewModel.description, axis: .vertical)
                    .lineLimit(2...5)
            }

            // Dynamic Fields
            if let type = viewModel.assetType {
                Section(type.displayName) {
                    ForEach(type.formFields) { field in
                        DynamicFormField(
                            field: field,
                            value: Binding(
                                get: { viewModel.metadata[field.key] ?? "" },
                                set: { viewModel.metadata[field.key] = $0 }
                            )
                        )
                    }
                }
            }

            // Value
            Section(String(localized: "asset.value")) {
                CurrencyInputField(
                    label: String(localized: "field.estimated_value"),
                    cents: $viewModel.estimatedValueCents,
                    currency: settingsStore.currency
                )
                CurrencyInputField(
                    label: String(localized: "field.purchase_price"),
                    cents: $viewModel.purchasePriceCents,
                    currency: settingsStore.currency
                )
                DatePicker(
                    String(localized: "field.purchase_date"),
                    selection: $viewModel.purchaseDate,
                    displayedComponents: .date
                )
            }

            // Submit
            Section {
                Button {
                    Task {
                        guard let userId = appState.currentUserId.flatMap({ UUID(uuidString: $0) }) else { return }
                        if let _ = await viewModel.submit(userId: userId) {
                            HapticService.success()
                            engagementStore.trackAssetCreated()
                            dismiss()
                        } else {
                            HapticService.error()
                        }
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.editingAsset != nil
                             ? String(localized: "save")
                             : String(localized: "asset.create"))
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }

            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - Dynamic Form Field

struct DynamicFormField: View {
    let field: AssetFormField
    @Binding var value: String

    private var localizedLabel: String {
        let base = NSLocalizedString(field.label, comment: "")
        return field.isRequired ? "\(base) *" : base
    }

    var body: some View {
        switch field {
        case .text:
            TextField(localizedLabel, text: $value)
        case .number:
            TextField(localizedLabel, text: $value)
                .keyboardType(.numberPad)
        case .decimal:
            TextField(localizedLabel, text: $value)
                .keyboardType(.decimalPad)
        case .currency:
            TextField(localizedLabel, text: $value)
                .keyboardType(.decimalPad)
        case .picker(_, _, let options, _):
            Picker(localizedLabel, selection: $value) {
                Text(String(localized: "select")).tag("")
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        case .date:
            TextField(localizedLabel, text: $value)
        }
    }
}

// MARK: - Currency Input

struct CurrencyInputField: View {
    let label: String
    @Binding var cents: Int?
    let currency: String
    @State private var text = ""

    var body: some View {
        TextField(label, text: $text)
            .keyboardType(.decimalPad)
            .onAppear {
                if let cents {
                    text = String(format: "%.2f", Double(cents) / 100.0)
                }
            }
            .onChange(of: text) { _, newValue in
                if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                    cents = Int(value * 100)
                } else if newValue.isEmpty {
                    cents = nil
                }
            }
    }
}
