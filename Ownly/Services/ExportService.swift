import Foundation
import UIKit
import PDFKit

/// Generates Digital Passport PDF and ZIP exports
final class ExportService {
    static let shared = ExportService()
    private init() {}

    struct ExportData {
        let asset: Asset
        let devices: [Device]
        let maintenance: [MaintenanceRecord]
        let documents: [AssetDocument]
        let media: [AssetMedia]
        let timeline: [TimelineEntry]
    }

    // MARK: - PDF Generation

    func generatePDF(from data: ExportData) -> Data {
        let pageWidth: CGFloat = 595.28  // A4
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var yOffset: CGFloat = 0

            func newPage() {
                context.beginPage()
                yOffset = margin
            }

            func checkPageBreak(needed: CGFloat) {
                if yOffset + needed > pageHeight - margin {
                    newPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .label, maxWidth: CGFloat? = nil) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let width = maxWidth ?? contentWidth
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                )
                checkPageBreak(needed: boundingRect.height + 8)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: yOffset, width: width, height: boundingRect.height),
                    withAttributes: attrs
                )
                yOffset += boundingRect.height + 8
            }

            func drawSeparator() {
                checkPageBreak(needed: 20)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yOffset))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                UIColor.separator.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                yOffset += 16
            }

            // --- Cover Page ---
            newPage()
            yOffset = pageHeight / 3

            let title = data.asset.assetType.isProperty
                ? String(localized: "export.digital_house_pass")
                : String(localized: "export.digital_asset_pass")

            drawText(title, font: .systemFont(ofSize: 28, weight: .bold), color: .systemBlue)
            drawText(data.asset.name, font: .systemFont(ofSize: 22, weight: .semibold))
            if let subtitle = data.asset.subtitle {
                drawText(subtitle, font: .systemFont(ofSize: 16), color: .secondaryLabel)
            }
            yOffset += 40
            let dateStr = Date().formatted(date: .long, time: .omitted)
            drawText(String(localized: "export.generated_on \(dateStr)"), font: .systemFont(ofSize: 12), color: .tertiaryLabel)
            drawText("Ownly", font: .systemFont(ofSize: 12, weight: .medium), color: .systemBlue)

            // --- Asset Details ---
            newPage()
            drawText(String(localized: "export.asset_details"), font: .systemFont(ofSize: 20, weight: .bold))
            drawSeparator()

            drawText("\(String(localized: "field.name")): \(data.asset.name)", font: .systemFont(ofSize: 14))
            drawText("\(String(localized: "field.type")): \(data.asset.assetType.displayName)", font: .systemFont(ofSize: 14))
            if let value = data.asset.displayValueCents {
                drawText("\(String(localized: "field.value")): \(value.formattedCurrency(code: data.asset.currency))", font: .systemFont(ofSize: 14))
            }
            if let date = data.asset.purchaseDate {
                drawText("\(String(localized: "field.purchase_date")): \(date.formatted(date: .long, time: .omitted))", font: .systemFont(ofSize: 14))
            }

            // Metadata
            for (key, val) in data.asset.metadata {
                if let str = val.stringValue, !str.isEmpty {
                    drawText("\(key): \(str)", font: .systemFont(ofSize: 13), color: .secondaryLabel)
                }
            }

            // --- Devices ---
            if !data.devices.isEmpty {
                yOffset += 16
                drawText(String(localized: "export.devices") + " (\(data.devices.count))", font: .systemFont(ofSize: 18, weight: .bold))
                drawSeparator()

                for device in data.devices {
                    checkPageBreak(needed: 80)
                    drawText(device.name, font: .systemFont(ofSize: 15, weight: .semibold))
                    if let mfr = device.manufacturer, let model = device.model {
                        drawText("\(mfr) \(model)", font: .systemFont(ofSize: 13), color: .secondaryLabel)
                    }
                    drawText("\(String(localized: "field.status")): \(device.status.displayName)", font: .systemFont(ofSize: 13), color: .secondaryLabel)
                    yOffset += 8
                }
            }

            // --- Maintenance ---
            if !data.maintenance.isEmpty {
                yOffset += 16
                drawText(String(localized: "export.maintenance") + " (\(data.maintenance.count))", font: .systemFont(ofSize: 18, weight: .bold))
                drawSeparator()

                let totalCost = data.maintenance.compactMap(\.costCents).reduce(0, +)
                drawText(String(localized: "export.total_cost") + ": \(totalCost.formattedCurrency(code: data.asset.currency))", font: .systemFont(ofSize: 14, weight: .medium))
                yOffset += 8

                for record in data.maintenance.prefix(50) {
                    checkPageBreak(needed: 60)
                    let dateStr = record.performedAt.formatted(date: .abbreviated, time: .omitted)
                    let costStr = record.costCents?.formattedCurrency(code: record.currency) ?? "–"
                    drawText("[\(dateStr)] \(record.title) — \(costStr)", font: .systemFont(ofSize: 13))
                }
            }

            // --- Statistics ---
            yOffset += 24
            drawText(String(localized: "export.statistics"), font: .systemFont(ofSize: 18, weight: .bold))
            drawSeparator()
            drawText("\(String(localized: "export.total_devices")): \(data.devices.count)", font: .systemFont(ofSize: 14))
            drawText("\(String(localized: "export.total_maintenance")): \(data.maintenance.count)", font: .systemFont(ofSize: 14))
            drawText("\(String(localized: "export.total_documents")): \(data.documents.count)", font: .systemFont(ofSize: 14))
            drawText("\(String(localized: "export.total_photos")): \(data.media.count)", font: .systemFont(ofSize: 14))
        }
    }

    // MARK: - Share

    func shareExport(data: Data, fileName: String, from viewController: UIViewController) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }
}
