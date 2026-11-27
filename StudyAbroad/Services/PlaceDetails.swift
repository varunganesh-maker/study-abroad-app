import CoreLocation
import Foundation

/// Small, plain helpers for the place page: which visits and memories belong to one place.
enum PlaceDetails {
    /// Visits closer than this count as "the same spot".
    static let sameSpotMeters: Double = 150
    /// Visits with the same name closer than this also count as the same place.
    static let sameNameMeters: Double = 1_000

    /// Straight-line distance in metres between two coordinates.
    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Every visit at the same place as `visit` (within 150 m, or the same name within 1 km),
    /// newest first. Includes `visit` itself.
    static func otherVisits(at visit: Visit, among visits: [Visit]) -> [Visit] {
        let name = visit.placeName.trimmingCharacters(in: .whitespaces).lowercased()
        var matches = visits.filter { other in
            if other === visit { return true }
            let distance = meters(visit.coordinate, other.coordinate)
            if distance <= sameSpotMeters { return true }
            let otherName = other.placeName.trimmingCharacters(in: .whitespaces).lowercased()
            return !name.isEmpty && name == otherName && distance <= sameNameMeters
        }
        if !matches.contains(where: { $0 === visit }) { matches.append(visit) }
        return matches.sorted { $0.arrival > $1.arrival }
    }

    /// Memories taken within `radius` metres of `coordinate`, newest first (undated ones last).
    static func memories(near coordinate: CLLocationCoordinate2D,
                         in memories: [PhotoMemory],
                         radius: Double = 150) -> [PhotoMemory] {
        memories
            .filter { meters(coordinate, $0.coordinate) <= radius }
            .sorted { ($0.takenAt ?? .distantPast) > ($1.takenAt ?? .distantPast) }
    }

    /// Average of the ratings that exist (visits without a rating are ignored). Nil if none.
    static func averageRating(of ratings: [Double?]) -> Double? {
        let rated = ratings.compactMap { $0 }
        guard !rated.isEmpty else { return nil }
        return rated.reduce(0, +) / Double(rated.count)
    }

    /// Average rating of these visits.
    static func averageRating(of visits: [Visit]) -> Double? {
        averageRating(of: visits.map { $0.rating })
    }
}
