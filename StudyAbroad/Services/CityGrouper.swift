import CoreLocation
import Foundation

/// Turns a flat list of geotagged memories into cities.
///
/// How it works:
/// 1. Memories inside a `KnownCity` circle go straight to that city (no network).
/// 2. Everything else is bucketed into ~10 km grid cells. One reverse-geocode per cell
///    (Apple's geocoder, free, results cached on the phone) gives the town name.
/// 3. Cells with the same town + country are merged.
actor CityGrouper {
    private struct Place: Codable, Hashable {
        let name: String
        let country: String?
    }

    /// Grid size in degrees (0.1° ≈ 11 km).
    private let cellSize = 0.1
    private let cacheKey = "CityGrouper.geocodeCache.v1"
    private var cache: [String: Place]
    private let geocoder = CLGeocoder()

    init() {
        if let data = UserDefaults.standard.data(forKey: "CityGrouper.geocodeCache.v1"),
           let saved = try? JSONDecoder().decode([String: Place].self, from: data) {
            cache = saved
        } else {
            cache = [:]
        }
    }

    /// Groups memories into cities. `onUpdate` is called with partial results while
    /// geocoding is still running, so the map fills in progressively.
    func group(
        _ memories: [PhotoMemory],
        onUpdate: @escaping @Sendable ([CityCluster], _ remainingLookups: Int) async -> Void
    ) async -> [CityCluster] {
        var assigned: [Place: [PhotoMemory]] = [:]
        var cells: [String: [PhotoMemory]] = [:]

        for memory in memories {
            if let city = KnownCity.match(memory.coordinate) {
                assigned[Place(name: city.name, country: city.country), default: []].append(memory)
            } else {
                cells[cellKey(memory.coordinate), default: []].append(memory)
            }
        }

        // Cells we already know the name of (from earlier launches).
        var pending: [(key: String, memories: [PhotoMemory])] = []
        for (key, cellMemories) in cells {
            if let place = cache[key] {
                assigned[place, default: []].append(contentsOf: cellMemories)
            } else {
                pending.append((key, cellMemories))
            }
        }
        // Biggest cells first, so the places you shot the most appear first.
        pending.sort { $0.memories.count > $1.memories.count }

        await onUpdate(buildClusters(assigned), pending.count)

        for (index, cell) in pending.enumerated() {
            if Task.isCancelled { break }
            let place = await lookUp(cellKey: cell.key, near: centroid(of: cell.memories))
            assigned[place, default: []].append(contentsOf: cell.memories)
            let remaining = pending.count - index - 1
            if remaining % 5 == 0 {
                saveCache()
                await onUpdate(buildClusters(assigned), remaining)
            }
        }
        saveCache()
        return buildClusters(assigned)
    }

    // MARK: - Helpers

    private func cellKey(_ c: CLLocationCoordinate2D) -> String {
        let lat = Int((c.latitude / cellSize).rounded(.down))
        let lon = Int((c.longitude / cellSize).rounded(.down))
        return "\(lat),\(lon)"
    }

    private func centroid(of memories: [PhotoMemory]) -> CLLocationCoordinate2D {
        let n = Double(max(memories.count, 1))
        let lat = memories.reduce(0) { $0 + $1.coordinate.latitude } / n
        let lon = memories.reduce(0) { $0 + $1.coordinate.longitude } / n
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Reverse-geocodes one point. Apple rate-limits this (~1 request/second),
    /// so we pace requests and retry once after a pause.
    private func lookUp(cellKey: String, near coordinate: CLLocationCoordinate2D) async -> Place {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        for attempt in 0..<3 {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                if let p = placemarks.first {
                    let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea
                        ?? p.name ?? p.ocean ?? "Somewhere"
                    let place = Place(name: name, country: p.country)
                    cache[cellKey] = place
                    return place
                }
                break
            } catch {
                // Throttled or offline: wait longer each time, then try again.
                try? await Task.sleep(nanoseconds: UInt64(2 + attempt * 3) * 1_000_000_000)
            }
        }
        // Not cached, so it gets retried on the next scan.
        return Place(name: "Unknown area", country: nil)
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func buildClusters(_ assigned: [Place: [PhotoMemory]]) -> [CityCluster] {
        assigned.map { place, memories in
            let sorted = memories.sorted { ($0.takenAt ?? .distantPast) > ($1.takenAt ?? .distantPast) }
            let known = KnownCity.all.first { $0.name == place.name && $0.country == place.country }
            return CityCluster(
                id: "\(place.name)|\(place.country ?? "")",
                name: place.name,
                country: place.country,
                center: known?.center ?? centroid(of: memories),
                memories: sorted
            )
        }
        .sorted { $0.memories.count > $1.memories.count }
    }
}
