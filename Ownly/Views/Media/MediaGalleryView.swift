import SwiftUI
import PhotosUI

struct MediaGalleryView: View {
    let assetId: UUID
    let userId: UUID

    @ObservedObject private var repository = MediaRepository.shared
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var selectedTypeFilter: MediaType?
    @State private var selectedMedia: AssetMedia?
    @State private var showingLightbox = false
    @State private var lightboxIndex = 0
    @State private var showingAddSheet = false
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var errorMessage: String?

    private var allMedia: [AssetMedia] {
        repository.mediaForAsset(assetId)
    }

    private var filteredMedia: [AssetMedia] {
        guard let filter = selectedTypeFilter else { return allMedia }
        return allMedia.filter { $0.type == filter }
    }

    private var beforeAfterPairs: [BeforeAfterPair] {
        repository.beforeAfterPairs(for: assetId)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            filterChipsBar

            if repository.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if filteredMedia.isEmpty && beforeAfterPairs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Before/After pairs section
                        if selectedTypeFilter == nil || selectedTypeFilter == .before || selectedTypeFilter == .after {
                            if !beforeAfterPairs.isEmpty {
                                beforeAfterSection
                            }
                        }

                        // Photo grid
                        if !filteredMedia.isEmpty {
                            photoGrid
                        }
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await repository.fetchForAsset(assetId)
                }
            }
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "media.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            String(localized: "media.add_photo"),
            isPresented: $showingAddSheet,
            titleVisibility: .visible
        ) {
            Button(String(localized: "media.take_photo")) {
                showingCamera = true
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Text(String(localized: "media.choose_from_gallery"))
            }
        }
        .fullScreenCover(isPresented: $showingLightbox) {
            MediaLightboxView(
                media: filteredMedia,
                currentIndex: $lightboxIndex
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView { image in
                Task { await uploadImage(image) }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadImage(image)
                }
                selectedPhotoItem = nil
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

                ForEach(MediaType.allCases) { type in
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

    // MARK: - Photo Grid

    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(filteredMedia.enumerated()), id: \.element.id) { index, media in
                MediaThumbnailCell(media: media)
                    .onTapGesture {
                        lightboxIndex = index
                        showingLightbox = true
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteMedia(media)
                        } label: {
                            Label(String(localized: "delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Before/After Section

    private var beforeAfterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(Color.ownlyPrimary)
                Text(String(localized: "media.before_after"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                Spacer()
                Text("\(beforeAfterPairs.count)")
                    .font(.caption.bold())
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.ownlyFill)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            ForEach(beforeAfterPairs) { pair in
                BeforeAfterComparisonCard(pair: pair)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text(String(localized: "media.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(Color.ownlyTextPrimary)

            Text(String(localized: "media.empty.description"))
                .font(.subheadline)
                .foregroundStyle(Color.ownlyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddSheet = true
            } label: {
                Label(String(localized: "media.add_photo"), systemImage: "plus.circle.fill")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ownlyPrimary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Actions

    private func uploadImage(_ image: UIImage) async {
        do {
            _ = try await repository.uploadPhoto(
                image: image,
                assetId: assetId,
                userId: userId,
                type: .photo
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMedia(_ media: AssetMedia) {
        Task {
            do {
                try await repository.delete(id: media.id, assetId: assetId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Media Thumbnail Cell

struct MediaThumbnailCell: View {
    let media: AssetMedia

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: media.thumbnailUrl ?? media.url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.ownlySecondaryBackground
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.ownlyTextTertiary)
                        }
                case .empty:
                    Color.ownlySecondaryBackground
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    Color.ownlySecondaryBackground
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()

            // Type badge
            HStack(spacing: 3) {
                Image(systemName: media.type.icon)
                    .font(.system(size: 8))
                Text(media.type.displayName)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(media.type.color.opacity(0.85))
            .clipShape(Capsule())
            .padding(4)
        }
    }
}

// MARK: - Before/After Comparison Card

struct BeforeAfterComparisonCard: View {
    let pair: BeforeAfterPair
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            // Side-by-side images
            HStack(spacing: 2) {
                // Before
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: pair.before.thumbnailUrl ?? pair.before.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Color.ownlySecondaryBackground
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .frame(height: 140)
                    .clipped()

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.caption2)
                        Text(String(localized: "media.before"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(MediaType.before.color)
                    .padding(.bottom, 6)
                }

                // After
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: pair.after.thumbnailUrl ?? pair.after.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Color.ownlySecondaryBackground
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .frame(height: 140)
                    .clipped()

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                        Text(String(localized: "media.after"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(MediaType.after.color)
                    .padding(.bottom, 6)
                }
            }

            // Footer with date range and cost
            HStack {
                Text("\(settingsStore.formatDate(pair.before.takenAt)) → \(settingsStore.formatDate(pair.after.takenAt))")
                    .font(.caption2)
                    .foregroundStyle(Color.ownlyTextTertiary)

                Spacer()

                if let cost = pair.linkedCostCents {
                    HStack(spacing: 3) {
                        Image(systemName: "banknote")
                            .font(.system(size: 9))
                        Text(settingsStore.formatCurrency(cost))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.ownlyPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.ownlyPrimary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.ownlySecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Media Lightbox

struct MediaLightboxView: View {
    let media: [AssetMedia]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    AsyncImage(url: URL(string: item.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                Text(String(localized: "media.load_failed"))
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }

            // Caption overlay
            if currentIndex < media.count {
                VStack {
                    Spacer()

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: media[currentIndex].type.icon)
                                .font(.caption)
                            Text(media[currentIndex].type.displayName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(media[currentIndex].type.color)

                        if let caption = media[currentIndex].caption, !caption.isEmpty {
                            Text(caption)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }

                        Text("\(currentIndex + 1) / \(media.count)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Camera Picker (UIImagePickerController Wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
