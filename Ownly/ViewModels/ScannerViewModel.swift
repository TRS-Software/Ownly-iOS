import SwiftUI
import PhotosUI

@MainActor
final class ScannerViewModel: ObservableObject {
    enum ScanMode: String, CaseIterable, Identifiable {
        case invoice, document, nameplate
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .invoice: return String(localized: "scan.mode.invoice")
            case .document: return String(localized: "scan.mode.document")
            case .nameplate: return String(localized: "scan.mode.nameplate")
            }
        }

        var icon: String {
            switch self {
            case .invoice: return "doc.text.fill"
            case .document: return "doc.fill"
            case .nameplate: return "tag.fill"
            }
        }
    }

    enum ScanStep {
        case selectMode
        case capture
        case processing
        case results
        case assignToAsset
    }

    @Published var mode: ScanMode = .invoice
    @Published var step: ScanStep = .selectMode
    @Published var capturedImage: UIImage?
    @Published var isProcessing = false
    @Published var confidence: Float = 0

    // Results
    @Published var rawText = ""
    @Published var invoiceData: OCRService.InvoiceData?
    @Published var nameplateData: OCRService.NameplateData?
    @Published var suggestedCategory: DocumentCategory = .other
    @Published var selectedAssetId: UUID?

    @Published var error: String?

    private let ocrService = OCRService.shared
    private let documentRepo = DocumentRepository.shared

    func selectMode(_ mode: ScanMode) {
        self.mode = mode
        step = .capture
    }

    func processImage(_ image: UIImage) async {
        capturedImage = image
        step = .processing
        isProcessing = true
        error = nil

        do {
            let result = try await ocrService.recognizeText(from: image)
            rawText = result.text
            confidence = result.confidence

            switch mode {
            case .invoice:
                invoiceData = ocrService.parseInvoice(from: result.text)
                suggestedCategory = invoiceData?.categoryGuess ?? .invoice

            case .document:
                suggestedCategory = ocrService.categorizeDocument(text: result.text)

            case .nameplate:
                nameplateData = ocrService.parseNameplate(from: result.text)
            }

            step = .results
        } catch {
            self.error = error.localizedDescription
            step = .capture
        }
        isProcessing = false
    }

    func saveAsDocument(assetId: UUID, userId: UUID, title: String) async -> Bool {
        let doc = AssetDocument(
            id: UUID(),
            assetId: assetId,
            deviceId: nil,
            userId: userId,
            category: suggestedCategory,
            title: title,
            fileUrl: "", // Would upload image first in production
            fileType: "image",
            fileSizeBytes: nil,
            ocrData: OcrData(
                amountCents: invoiceData?.amountCents,
                date: invoiceData?.date,
                vendor: invoiceData?.vendor,
                categoryGuess: suggestedCategory.rawValue,
                rawText: rawText
            ),
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try await documentRepo.create(doc)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func reset() {
        step = .selectMode
        capturedImage = nil
        rawText = ""
        invoiceData = nil
        nameplateData = nil
        confidence = 0
        error = nil
    }
}
