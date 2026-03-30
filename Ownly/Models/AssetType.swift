import SwiftUI

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case house
    case apartment
    case car
    case motorcycle
    case boat
    case watch
    case jewelry
    case electronics
    case art
    case cash
    case stocks
    case crypto
    case land
    case commercial
    case custom

    var id: String { rawValue }

    var displayName: String {
        String(localized: LocalizedStringResource(stringLiteral: "asset_type.\(rawValue)"))
    }

    var icon: String {
        switch self {
        case .house: return "house.fill"
        case .apartment: return "building.2.fill"
        case .car: return "car.fill"
        case .motorcycle: return "bicycle"
        case .boat: return "ferry.fill"
        case .watch: return "clock.fill"
        case .jewelry: return "sparkles"
        case .electronics: return "desktopcomputer"
        case .art: return "paintpalette.fill"
        case .cash: return "banknote.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .crypto: return "bitcoinsign.circle.fill"
        case .land: return "map.fill"
        case .commercial: return "storefront.fill"
        case .custom: return "cube.fill"
        }
    }

    var color: Color {
        switch self {
        case .house, .apartment, .land, .commercial: return .assetProperty
        case .car, .motorcycle, .boat: return .assetVehicle
        case .watch, .jewelry, .art: return .assetLuxury
        case .electronics: return .assetElectronics
        case .cash, .stocks, .crypto: return .assetFinancial
        case .custom: return .assetOther
        }
    }

    var category: AssetCategory {
        switch self {
        case .house, .apartment, .land, .commercial: return .property
        case .car, .motorcycle, .boat: return .vehicle
        case .watch, .jewelry, .art: return .luxury
        case .electronics: return .electronics
        case .cash, .stocks, .crypto: return .financial
        case .custom: return .other
        }
    }

    var isRentable: Bool {
        switch self {
        case .house, .apartment, .commercial: return true
        default: return false
        }
    }

    var hasLivePrices: Bool {
        switch self {
        case .stocks, .crypto: return true
        default: return false
        }
    }

    var isProperty: Bool {
        switch self {
        case .house, .apartment, .land, .commercial: return true
        default: return false
        }
    }

    var deviceCategories: [DeviceCategory] {
        switch self.category {
        case .property:
            return [.heating, .sanitary, .electrical, .roof, .windows, .doors, .kitchen, .other]
        case .vehicle:
            return [.engine, .brakes, .tires, .battery, .exhaust, .suspension, .other]
        case .electronics:
            return [.battery, .display, .storage, .other]
        default:
            return [.other]
        }
    }

    /// Dynamic form fields for this asset type
    var formFields: [AssetFormField] {
        switch self {
        case .house:
            return [
                .text(key: "address", label: "field.address", required: true),
                .text(key: "zip", label: "field.zip", required: true),
                .text(key: "city", label: "field.city", required: true),
                .text(key: "country", label: "field.country"),
                .number(key: "year_built", label: "field.year_built"),
                .number(key: "area_sqm", label: "field.area_sqm"),
                .number(key: "floors", label: "field.floors"),
                .number(key: "rooms", label: "field.rooms"),
            ]
        case .apartment:
            return [
                .text(key: "address", label: "field.address", required: true),
                .text(key: "zip", label: "field.zip", required: true),
                .text(key: "city", label: "field.city", required: true),
                .number(key: "floor", label: "field.floor"),
                .number(key: "area_sqm", label: "field.area_sqm"),
                .number(key: "rooms", label: "field.rooms"),
            ]
        case .car:
            return [
                .text(key: "brand", label: "field.brand", required: true),
                .text(key: "model", label: "field.model", required: true),
                .number(key: "year", label: "field.year"),
                .text(key: "vin", label: "field.vin"),
                .text(key: "license_plate", label: "field.license_plate"),
                .number(key: "mileage", label: "field.mileage"),
                .picker(key: "fuel_type", label: "field.fuel_type", options: ["gasoline", "diesel", "electric", "hybrid", "gas"]),
                .text(key: "color", label: "field.color"),
            ]
        case .motorcycle:
            return [
                .text(key: "brand", label: "field.brand", required: true),
                .text(key: "model", label: "field.model", required: true),
                .number(key: "year", label: "field.year"),
                .number(key: "displacement_cc", label: "field.displacement"),
                .number(key: "mileage", label: "field.mileage"),
            ]
        case .boat:
            return [
                .text(key: "brand", label: "field.brand"),
                .text(key: "model", label: "field.model"),
                .number(key: "year", label: "field.year"),
                .number(key: "length_m", label: "field.length_m"),
                .text(key: "registration", label: "field.registration"),
            ]
        case .watch:
            return [
                .text(key: "brand", label: "field.brand", required: true),
                .text(key: "model", label: "field.model", required: true),
                .text(key: "reference_number", label: "field.reference_number"),
                .number(key: "year", label: "field.year"),
                .text(key: "serial_number", label: "field.serial_number"),
            ]
        case .jewelry:
            return [
                .text(key: "type", label: "field.type", required: true),
                .text(key: "material", label: "field.material"),
                .number(key: "weight_g", label: "field.weight_g"),
                .text(key: "gemstones", label: "field.gemstones"),
            ]
        case .electronics:
            return [
                .text(key: "brand", label: "field.brand", required: true),
                .text(key: "model", label: "field.model", required: true),
                .text(key: "serial_number", label: "field.serial_number"),
                .number(key: "year", label: "field.year"),
            ]
        case .art:
            return [
                .text(key: "artist", label: "field.artist", required: true),
                .text(key: "title", label: "field.title"),
                .number(key: "year", label: "field.year"),
                .text(key: "medium", label: "field.medium"),
                .text(key: "dimensions", label: "field.dimensions"),
            ]
        case .stocks:
            return [
                .text(key: "ticker", label: "field.ticker", required: true),
                .text(key: "company", label: "field.company"),
                .number(key: "shares", label: "field.shares"),
                .currency(key: "price_per_share_cents", label: "field.price_per_share"),
                .text(key: "broker", label: "field.broker"),
            ]
        case .crypto:
            return [
                .text(key: "coin_id", label: "field.coin", required: true),
                .text(key: "symbol", label: "field.symbol"),
                .decimal(key: "amount", label: "field.amount"),
                .currency(key: "price_per_unit_cents", label: "field.price_per_unit"),
                .text(key: "wallet", label: "field.wallet"),
            ]
        case .cash:
            return [
                .text(key: "bank", label: "field.bank"),
                .text(key: "account_type", label: "field.account_type"),
                .text(key: "iban", label: "field.iban"),
            ]
        case .land:
            return [
                .text(key: "address", label: "field.address", required: true),
                .text(key: "zip", label: "field.zip"),
                .text(key: "city", label: "field.city"),
                .number(key: "area_sqm", label: "field.area_sqm"),
                .text(key: "land_register", label: "field.land_register"),
            ]
        case .commercial:
            return [
                .text(key: "address", label: "field.address", required: true),
                .text(key: "zip", label: "field.zip"),
                .text(key: "city", label: "field.city"),
                .number(key: "area_sqm", label: "field.area_sqm"),
                .text(key: "business_type", label: "field.business_type"),
            ]
        case .custom:
            return [
                .text(key: "category", label: "field.category"),
                .text(key: "serial_number", label: "field.serial_number"),
            ]
        }
    }
}

enum AssetCategory: String, Codable {
    case property
    case vehicle
    case luxury
    case electronics
    case financial
    case other
}

enum AssetFormField: Identifiable {
    case text(key: String, label: String, required: Bool = false)
    case number(key: String, label: String, required: Bool = false)
    case decimal(key: String, label: String, required: Bool = false)
    case currency(key: String, label: String, required: Bool = false)
    case picker(key: String, label: String, options: [String], required: Bool = false)
    case date(key: String, label: String, required: Bool = false)

    var id: String { key }

    var key: String {
        switch self {
        case .text(let k, _, _), .number(let k, _, _), .decimal(let k, _, _),
             .currency(let k, _, _), .picker(let k, _, _, _), .date(let k, _, _):
            return k
        }
    }

    var label: String {
        switch self {
        case .text(_, let l, _), .number(_, let l, _), .decimal(_, let l, _),
             .currency(_, let l, _), .picker(_, let l, _, _), .date(_, let l, _):
            return l
        }
    }

    var isRequired: Bool {
        switch self {
        case .text(_, _, let r), .number(_, _, let r), .decimal(_, _, let r),
             .currency(_, _, let r), .picker(_, _, _, let r), .date(_, _, let r):
            return r
        }
    }
}
