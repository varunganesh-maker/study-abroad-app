import Foundation

/// "Find a city": matches what you type against city names, countries and your captions.
/// Everything happens in memory on the phone; nothing is saved or sent anywhere.
enum CitySearch {
    struct Result: Identifiable {
        let city: CityCluster
        /// A bit of the caption that matched, when the city matched only because of a caption.
        let snippet: String?
        var id: String { city.id }
    }

    /// Cities matching `query`, best matches first:
    /// name starts with it, then name contains it, then country, then a caption in that city.
    /// An empty query lists every city, newest memories first.
    /// `captions` are by memory id (only memories on the map are searched, so removed ones never show up).
    static func search(_ query: String, in cities: [CityCluster], captions: [String: String]) -> [Result] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return cities
                .sorted { $0.newestDate > $1.newestDate }
                .map { Result(city: $0, snippet: nil) }
        }
        var ranked: [(rank: Int, result: Result)] = []
        for city in cities {
            if hasPrefix(city.name, q) {
                ranked.append((0, Result(city: city, snippet: nil)))
            } else if city.name.localizedStandardContains(q) {
                ranked.append((1, Result(city: city, snippet: nil)))
            } else if let country = city.country, country.localizedStandardContains(q) {
                ranked.append((2, Result(city: city, snippet: nil)))
            } else if let caption = city.memories.lazy.compactMap({ captions[$0.id] })
                        .first(where: { $0.localizedStandardContains(q) }) {
                ranked.append((3, Result(city: city, snippet: snippet(of: caption, around: q))))
            }
        }
        return ranked
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.result.city.memories.count > $1.result.city.memories.count }
            .map(\.result)
    }

    /// "Bondi" matches "bondi beach" and "Böndi" (ignores capitals and accents).
    private static func hasPrefix(_ text: String, _ prefix: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .anchored]
        return text.range(of: prefix, options: options) != nil
    }

    /// Up to ~60 characters of the caption around the match, on one line.
    static func snippet(of caption: String, around query: String) -> String {
        let flat = caption.replacingOccurrences(of: "\n", with: " ")
        guard flat.count > 60,
              let range = flat.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return flat
        }
        let start = flat.index(range.lowerBound, offsetBy: -20, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(start, offsetBy: 60, limitedBy: flat.endIndex) ?? flat.endIndex
        let before = start == flat.startIndex ? "" : "…"
        let after = end == flat.endIndex ? "" : "…"
        return before + String(flat[start..<end]) + after
    }
}
