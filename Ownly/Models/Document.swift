import Foundation
import SwiftUI

struct AssetDocument: Codable, Identifiable, Hashable {
    let id: UUID
    var assetId: UUID
    var deviceId: UUID?
    var userId: UUID
    var category: DocumentCategory
    var title: String
    var fileUrl: String
    var fileType: String?
    var fileSizeBytes: Int?
    var ocrData: OcrData?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case deviceId = "device_id"
        case userId = "user_id"
        case category, title
        case fileUrl = "file_url"
        case fileType = "file_type"
        case fileSizeBytes = "file_size_bytes"
        case ocrData = "ocr_data"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var fileSizeFormatted: String? {
        guard let bytes = fileSizeBytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func == (lhs: AssetDocument, rhs: AssetDocument) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case invoice
    case contract
    case certificate
    case manual
    case report
    case insurance
    case other

    var id: String { rawValue }

    var displayName: String {
        String(localized: LocalizedStringResource(stringLiteral: "doc_category.\(rawValue)"))
    }

    var icon: String {
        switch self {
        case .invoice: return "doc.text.fill"
        case .contract: return "signature"
        case .certificate: return "checkmark.seal.fill"
        case .manual: return "book.fill"
        case .report: return "chart.bar.doc.horizontal.fill"
        case .insurance: return "shield.fill"
        case .other: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .invoice: return .blue
        case .contract: return .purple
        case .certificate: return .green
        case .manual: return .orange
        case .report: return .indigo
        case .insurance: return .teal
        case .other: return .gray
        }
    }
}

struct OcrData: Codable, Hashable {
    var amountCents: Int?
    var date: String?
    var vendor: String?
    var categoryGuess: String?
    var rawText: String?

    enum CodingKeys: String, CodingKey {
        case amountCents = "amount_cents"
        case date, vendor
        case categoryGuess = "category_guess"
        case rawText = "raw_text"
    }
}
