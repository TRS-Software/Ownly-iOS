import Foundation
import Vision
import UIKit

/// Native Apple Vision OCR — no cloud API, fully on-device
final class OCRService {
    static let shared = OCRService()
    private init() {}

    enum OCRMode {
        case invoice
        case document
        case nameplate
    }

    struct OCRResult {
        let text: String
        let confidence: Float
        let blocks: [TextBlock]
    }

    struct TextBlock {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    // MARK: - Core OCR (Apple Vision)

    func recognizeText(from image: UIImage, languages: [String] = ["de-DE", "en-US"]) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noResults)
                    return
                }

                var blocks: [TextBlock] = []
                var fullText = ""
                var totalConfidence: Float = 0

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    fullText += candidate.string + "\n"
                    totalConfidence += candidate.confidence
                    blocks.append(TextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    ))
                }

                let avgConfidence = blocks.isEmpty ? 0 : totalConfidence / Float(blocks.count)
                continuation.resume(returning: OCRResult(
                    text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: avgConfidence,
                    blocks: blocks
                ))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Invoice Parsing

    struct InvoiceData {
        var amountCents: Int?
        var date: String?
        var vendor: String?
        var invoiceNumber: String?
        var categoryGuess: DocumentCategory?
    }

    func parseInvoice(from text: String) -> InvoiceData {
        var data = InvoiceData()

        // Amount extraction (EUR formats: 1.234,56 / 1,234.56 / 1234.56)
        let amountPatterns = [
            #"(?:Gesamt|Total|Summe|Betrag|Amount|Endbetrag|Brutto|Netto)[\s:]*(?:EUR|€)?\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#,
            #"(?:EUR|€)\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#,
            #"(\d{1,3}(?:\.\d{3})*,\d{2})\s*(?:EUR|€)"#,
        ]

        for pattern in amountPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                if let amount = extractAmount(from: matched) {
                    data.amountCents = amount
                    break
                }
            }
        }

        // Date extraction (DD.MM.YYYY)
        let datePattern = #"(\d{2}\.\d{2}\.\d{4})"#
        if let match = text.range(of: datePattern, options: .regularExpression) {
            let dateStr = String(text[match])
            data.date = convertGermanDate(dateStr)
        }

        // Invoice number
        let invoicePatterns = [
            #"(?:Rechnung|Invoice|Rechnungs-?Nr\.?|Invoice\s*No\.?)[\s.:]*([A-Z0-9\-]+)"#,
        ]
        for pattern in invoicePatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                data.invoiceNumber = String(text[match])
                    .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
                    .last
                break
            }
        }

        // Vendor (first substantial line that's not a date/number)
        let lines = text.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 3 && !trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " }) {
                data.vendor = trimmed
                break
            }
        }

        // Category guess
        data.categoryGuess = categorizeDocument(text: text)

        return data
    }

    // MARK: - Nameplate Parsing

    struct NameplateData {
        var manufacturer: String?
        var model: String?
        var serialNumber: String?
        var yearOfManufacture: Int?
    }

    func parseNameplate(from text: String) -> NameplateData {
        var data = NameplateData()

        let snPatterns = [
            #"(?:S/?N|Serial|Serien-?Nr\.?)[\s.:]*([A-Z0-9\-]+)"#,
        ]
        for pattern in snPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                data.serialNumber = String(text[match]).components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
                break
            }
        }

        let modelPatterns = [
            #"(?:Model|Modell|Type|Typ)[\s.:]*(.+)"#,
        ]
        for pattern in modelPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                data.model = String(text[match]).components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Year
        let yearPattern = #"(?:Baujahr|Year|BJ\.?)[\s.:]*(\d{4})"#
        if let match = text.range(of: yearPattern, options: [.regularExpression, .caseInsensitive]) {
            let yearStr = String(text[match])
            if let year = Int(yearStr.filter(\.isNumber).suffix(4)) {
                data.yearOfManufacture = year
            }
        }

        // Manufacturer (first non-empty line)
        let lines = text.components(separatedBy: .newlines)
        if let first = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).count > 2 }) {
            data.manufacturer = first.trimmingCharacters(in: .whitespaces)
        }

        return data
    }

    // MARK: - Document Categorization

    func categorizeDocument(text: String) -> DocumentCategory {
        let lower = text.lowercased()

        let keywords: [(DocumentCategory, [String])] = [
            (.invoice, ["rechnung", "invoice", "betrag", "mwst", "netto", "brutto", "summe", "fällig"]),
            (.contract, ["vertrag", "contract", "vereinbarung", "laufzeit", "kündigung", "agreement"]),
            (.certificate, ["zertifikat", "certificate", "bescheinigung", "nachweis", "prüfbericht", "tüv"]),
            (.manual, ["anleitung", "manual", "bedienungsanleitung", "gebrauchsanweisung", "handbuch"]),
            (.report, ["bericht", "report", "gutachten", "protokoll", "assessment"]),
            (.insurance, ["versicherung", "insurance", "police", "deckung", "prämie", "beitrag"]),
        ]

        var bestMatch: DocumentCategory = .other
        var bestScore = 0

        for (category, words) in keywords {
            let score = words.filter { lower.contains($0) }.count
            if score > bestScore {
                bestScore = score
                bestMatch = category
            }
        }

        return bestMatch
    }

    // MARK: - Helpers

    private func extractAmount(from text: String) -> Int? {
        let digits = text.replacingOccurrences(of: "[^0-9,.]", with: "", options: .regularExpression)
        // German format: 1.234,56
        if digits.contains(",") {
            let parts = digits.components(separatedBy: ",")
            if parts.count == 2 {
                let whole = parts[0].replacingOccurrences(of: ".", with: "")
                let fraction = parts[1].prefix(2)
                if let wholeInt = Int(whole), let fracInt = Int(fraction) {
                    return wholeInt * 100 + fracInt
                }
            }
        }
        // Fallback: try as Double
        if let value = Double(digits) {
            return Int(value * 100)
        }
        return nil
    }

    private func convertGermanDate(_ dateStr: String) -> String? {
        let parts = dateStr.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        return "\(parts[2])-\(parts[1])-\(parts[0])"
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidImage: return String(localized: "error.ocr.invalid_image")
        case .noResults: return String(localized: "error.ocr.no_results")
        }
    }
}
