import Foundation

/// Fetches live prices for stocks (Yahoo Finance) and crypto (CoinGecko)
final class LivePriceService {
    static let shared = LivePriceService()
    private init() {}

    struct PriceData {
        let pricePerUnit: Double
        let change24h: Double?
        let changePercent24h: Double?
        let currency: String
        let lastUpdated: Date
    }

    // MARK: - CoinGecko (Crypto)

    func fetchCryptoPrice(coinId: String, currency: String = "eur") async throws -> PriceData {
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(coinId)&vs_currencies=\(currency)&include_24hr_change=true"
        guard let url = URL(string: urlString) else { throw PriceError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let coinData = json?[coinId] as? [String: Any],
              let price = coinData[currency] as? Double else {
            throw PriceError.noData
        }

        let change = coinData["\(currency)_24h_change"] as? Double

        return PriceData(
            pricePerUnit: price,
            change24h: nil,
            changePercent24h: change,
            currency: currency.uppercased(),
            lastUpdated: Date()
        )
    }

    // MARK: - Yahoo Finance (Stocks/ETFs)

    func fetchStockPrice(ticker: String) async throws -> PriceData {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=2d"
        guard let url = URL(string: urlString) else { throw PriceError.invalidURL }

        var request = URLRequest(url: url)
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let chart = json?["chart"] as? [String: Any],
              let results = (chart["result"] as? [[String: Any]])?.first,
              let meta = results["meta"] as? [String: Any],
              let regularMarketPrice = meta["regularMarketPrice"] as? Double else {
            throw PriceError.noData
        }

        let previousClose = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double
        let currency = (meta["currency"] as? String) ?? "USD"

        var change24h: Double?
        var changePercent: Double?
        if let prev = previousClose, prev > 0 {
            change24h = regularMarketPrice - prev
            changePercent = ((regularMarketPrice - prev) / prev) * 100
        }

        return PriceData(
            pricePerUnit: regularMarketPrice,
            change24h: change24h,
            changePercent24h: changePercent,
            currency: currency,
            lastUpdated: Date()
        )
    }

    // MARK: - Unified

    func fetchPrice(for asset: Asset) async throws -> PriceData {
        switch asset.assetType {
        case .crypto:
            let coinId = asset.metadataString("coin_id") ?? ""
            let currency = asset.currency.lowercased()
            return try await fetchCryptoPrice(coinId: coinId, currency: currency)

        case .stocks:
            let ticker = asset.metadataString("ticker") ?? ""
            return try await fetchStockPrice(ticker: ticker)

        default:
            throw PriceError.unsupportedType
        }
    }
}

enum PriceError: LocalizedError {
    case invalidURL
    case noData
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No price data available"
        case .unsupportedType: return "Asset type does not support live prices"
        }
    }
}

// MARK: - Popular Crypto Coins

struct CryptoCoin: Identifiable {
    let id: String
    let name: String
    let symbol: String

    static let popular: [CryptoCoin] = [
        CryptoCoin(id: "bitcoin", name: "Bitcoin", symbol: "BTC"),
        CryptoCoin(id: "ethereum", name: "Ethereum", symbol: "ETH"),
        CryptoCoin(id: "tether", name: "Tether", symbol: "USDT"),
        CryptoCoin(id: "binancecoin", name: "BNB", symbol: "BNB"),
        CryptoCoin(id: "solana", name: "Solana", symbol: "SOL"),
        CryptoCoin(id: "ripple", name: "XRP", symbol: "XRP"),
        CryptoCoin(id: "usd-coin", name: "USD Coin", symbol: "USDC"),
        CryptoCoin(id: "cardano", name: "Cardano", symbol: "ADA"),
        CryptoCoin(id: "dogecoin", name: "Dogecoin", symbol: "DOGE"),
        CryptoCoin(id: "polkadot", name: "Polkadot", symbol: "DOT"),
        CryptoCoin(id: "avalanche-2", name: "Avalanche", symbol: "AVAX"),
        CryptoCoin(id: "chainlink", name: "Chainlink", symbol: "LINK"),
        CryptoCoin(id: "litecoin", name: "Litecoin", symbol: "LTC"),
        CryptoCoin(id: "matic-network", name: "Polygon", symbol: "MATIC"),
    ]
}
