import CoreLocation

/// Apple's geocoder names Australian *suburbs* ("Bondi Beach", "Surry Hills"),
/// not cities. So anything inside one of these circles is filed under the big city.
/// Add a line here to teach the app a new city.
struct KnownCity {
    let name: String
    let country: String
    let center: CLLocationCoordinate2D
    let radiusKm: Double

    static let all: [KnownCity] = [
        .init("Sydney", -33.8688, 151.2093, 45),
        .init("Melbourne", -37.8136, 144.9631, 45),
        .init("Brisbane", -27.4698, 153.0251, 35),
        .init("Gold Coast", -28.0167, 153.4000, 30),
        .init("Sunshine Coast", -26.6500, 153.0667, 30),
        .init("Perth", -31.9505, 115.8605, 40),
        .init("Adelaide", -34.9285, 138.6007, 35),
        .init("Canberra", -35.2809, 149.1300, 25),
        .init("Hobart", -42.8821, 147.3272, 25),
        .init("Darwin", -12.4634, 130.8456, 25),
        .init("Cairns", -16.9186, 145.7781, 25),
        .init("Townsville", -19.2590, 146.8169, 20),
        .init("Newcastle", -32.9283, 151.7817, 25),
        .init("Wollongong", -34.4278, 150.8931, 20),
        .init("Geelong", -38.1499, 144.3617, 20),
        .init("Byron Bay", -28.6474, 153.6020, 15),
    ]

    private init(_ name: String, _ lat: Double, _ lon: Double, _ radiusKm: Double, country: String = "Australia") {
        self.name = name
        self.country = country
        self.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        self.radiusKm = radiusKm
    }

    /// The nearest known city whose circle contains the coordinate, if any.
    static func match(_ coordinate: CLLocationCoordinate2D) -> KnownCity? {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return all
            .map { city in (city, point.distance(from: CLLocation(latitude: city.center.latitude, longitude: city.center.longitude)) / 1000) }
            .filter { $0.1 <= $0.0.radiusKm }
            .min { $0.1 < $1.1 }?
            .0
    }
}
