import Foundation

enum OpenFoodFactsError: Error, LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Unexpected response from Open Food Facts"
    }
}

/// Calls Open Food Facts directly from the app - it's a free public API,
/// no key needed, so no reason to proxy it through our own backend.
final class OpenFoodFactsService {
    private var searchURL: URL {
        URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!
    }

    func search(term: String) async throws -> [OpenFoodFactsProduct] {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: term),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]]
        else {
            throw OpenFoodFactsError.invalidResponse
        }

        // Open Food Facts data is community-submitted and inconsistent -
        // parse defensively rather than with a strict Codable model that
        // would fail the whole batch on one malformed entry.
        return products.compactMap { product -> OpenFoodFactsProduct? in
            guard let name = product["product_name"] as? String, !name.isEmpty else { return nil }
            let nutriments = product["nutriments"] as? [String: Any] ?? [:]

            func number(_ key: String) -> Double {
                if let value = nutriments[key] as? Double { return value }
                if let value = nutriments[key] as? Int { return Double(value) }
                if let value = nutriments[key] as? String { return Double(value) ?? 0 }
                return 0
            }

            let code = product["code"] as? String ?? UUID().uuidString
            let brand = (product["brands"] as? String)?
                .split(separator: ",").first
                .map { $0.trimmingCharacters(in: .whitespaces) }

            return OpenFoodFactsProduct(
                id: code,
                name: name,
                brand: brand,
                caloriesPer100g: number("energy-kcal_100g"),
                proteinPer100g: number("proteins_100g"),
                carbsPer100g: number("carbohydrates_100g"),
                fatPer100g: number("fat_100g")
            )
        }
    }
}
