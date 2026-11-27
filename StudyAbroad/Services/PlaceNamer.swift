import CoreLocation
import MapKit

/// Turns a coordinate into a place name ("AP Bakery"), suburb ("Surry Hills") and city ("Sydney").
enum PlaceNamer {
    struct Place {
        var name: String?
        var area: String?
        var city: String?
    }

    static func lookUp(_ coordinate: CLLocationCoordinate2D) async -> Place {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var place = Place()
        var streetAddress: String?

        // 1. Suburb and city from Apple's geocoder.
        if let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            place.area = mark.subLocality ?? mark.locality
            place.city = mark.locality
            streetAddress = mark.name
        }
        // Same trick as the map: inside Sydney's circle means "Sydney", not "Bondi Beach".
        if let known = KnownCity.match(coordinate) { place.city = known.name }

        // 2. The nearest café, shop, park, museum… within about 75 m.
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 75)
        if let response = try? await MKLocalSearch(request: request).start() {
            let nearest = response.mapItems.min { a, b in
                distance(a, from: location) < distance(b, from: location)
            }
            place.name = nearest?.name
        }

        // 3. Nothing nearby: fall back to the street address or suburb.
        if place.name == nil { place.name = streetAddress ?? place.area }
        return place
    }

    private static func distance(_ item: MKMapItem, from location: CLLocation) -> CLLocationDistance {
        let c = item.placemark.coordinate
        return CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: location)
    }
}
