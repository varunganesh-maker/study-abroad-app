import CoreLocation
import MapKit

/// The City / Country / World switch above the map.
/// The middle option is named after a real country ("Australia", "United States"), which changes
/// with where you are and where the map is pointing.
enum MapScope: String, CaseIterable, Identifiable {
    case city, country, world

    var id: String { rawValue }

    /// The label on the switch. `country` is the name to show for the middle option.
    func title(country: String?) -> String {
        switch self {
        case .city: "City"
        case .country: country ?? "Country"
        case .world: "World"
        }
    }

    /// Which option best describes what the map is showing after you pinch or pan
    /// (`span` = how many degrees of latitude are on screen).
    static func matching(span: Double) -> MapScope {
        if span < 4 { return .city }
        if span < 50 { return .country }
        return .world
    }

    // MARK: Regions

    /// A city and its surroundings (about 55 km top to bottom).
    static func cityRegion(_ center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
    }

    /// The whole world, centred on the longitude you care about (where you are), if known.
    static func worldRegion(centeredOn longitude: Double?) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 15, longitude: longitude ?? 140),
                           span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 300))
    }

    /// The whole of a country. Uses a known outline for common countries; otherwise fits every
    /// city you have memories in there, with some room around them.
    static func countryRegion(_ country: String, cities: [CityCluster]) -> MKCoordinateRegion? {
        if let known = knownCountries[country.lowercased()] { return known }
        let centers = cities.filter { $0.country == country }.map(\.center)
        guard let first = centers.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in centers {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let span = MKCoordinateSpan(latitudeDelta: min(max((maxLat - minLat) * 1.4, 8), 60),
                                    longitudeDelta: min(max((maxLon - minLon) * 1.4, 8), 120))
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center, span: span)
    }

    /// Rough outlines of countries Varun is likely to visit (names as Apple's geocoder writes them).
    private static let knownCountries: [String: MKCoordinateRegion] = {
        func region(_ lat: Double, _ lon: Double, _ dLat: Double, _ dLon: Double) -> MKCoordinateRegion {
            MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                               span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon))
        }
        return [
            "australia": region(-27.5, 134, 40, 42),
            "new zealand": region(-41, 173, 15, 15),
            "united states": region(38.5, -97, 28, 60),
            "canada": region(57, -96, 35, 70),
            "united kingdom": region(54.5, -3, 12, 12),
            "japan": region(37, 138, 20, 20),
            "indonesia": region(-2.5, 118, 20, 45),
            "thailand": region(13, 101, 17, 12),
            "india": region(22, 79, 30, 30),
            "fiji": region(-17.8, 178, 4, 4),
            "singapore": region(1.35, 103.82, 0.6, 0.6),
        ]
    }()

    // MARK: Which city

    /// The city closest to a point (e.g. the middle of the map), if there are any cities.
    static func nearestCity(to point: CLLocationCoordinate2D, in cities: [CityCluster]) -> CityCluster? {
        let here = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return cities.min { a, b in
            CLLocation(latitude: a.center.latitude, longitude: a.center.longitude).distance(from: here)
                < CLLocation(latitude: b.center.latitude, longitude: b.center.longitude).distance(from: here)
        }
    }

    /// The city to open the map on: the one you're in (within 60 km), else the one with your newest memory.
    static func focusCity(location: CLLocation?, cities: [CityCluster]) -> (city: CityCluster, isHere: Bool)? {
        if let location, let nearest = nearestCity(to: location.coordinate, in: cities) {
            let distance = CLLocation(latitude: nearest.center.latitude, longitude: nearest.center.longitude)
                .distance(from: location)
            if distance < 60_000 { return (nearest, true) }
        }
        let latest = cities.max { $0.newestDate < $1.newestDate }
        return latest.map { ($0, false) }
    }
}
