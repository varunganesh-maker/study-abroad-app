import CoreLocation
import MapKit
import Foundation
import Testing
@testable import StudyAbroad

/// The City / Country / World switch: which option fits, regions, and which city to open on.
struct MapScopeTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func city(_ name: String, country: String?, lat: Double, lon: Double, daysLater: Double = 0) -> CityCluster {
        let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let m = PhotoMemory(id: "\(name)-1", coordinate: c, takenAt: base.addingTimeInterval(daysLater * 86_400), isVideo: false)
        return CityCluster(id: "\(name)|\(country ?? "")", name: name, country: country, center: c, memories: [m])
    }

    private let sydney = (lat: -33.8688, lon: 151.2093)
    private let melbourne = (lat: -37.8136, lon: 144.9631)

    @Test func matchingSpanThresholds() {
        #expect(MapScope.matching(span: 0.5) == .city)
        #expect(MapScope.matching(span: 3.99) == .city)
        #expect(MapScope.matching(span: 4) == .country)
        #expect(MapScope.matching(span: 49.9) == .country)
        #expect(MapScope.matching(span: 50) == .world)
        #expect(MapScope.matching(span: 140) == .world)
    }

    @Test func titleFallsBackToCountry() {
        #expect(MapScope.city.title(country: "Australia") == "City")
        #expect(MapScope.world.title(country: "Australia") == "World")
        #expect(MapScope.country.title(country: "Australia") == "Australia")
        #expect(MapScope.country.title(country: nil) == "Country")
    }

    @Test func knownCountryUsesItsOutlineWhateverTheCase() {
        let region = MapScope.countryRegion("Australia", cities: [])
        #expect(region?.span.latitudeDelta == 40)
        #expect(region?.center.longitude == 134)
        #expect(MapScope.countryRegion("australia", cities: []) != nil)
    }

    @Test func unknownCountryFitsItsCitiesWithMinimumSpan() throws {
        let a = city("Aville", country: "Freedonia", lat: 10, lon: 20)
        let b = city("Bville", country: "Freedonia", lat: 12, lon: 24)
        let other = city("Elsewhere", country: "Sylvania", lat: 60, lon: 100)
        let region = try #require(MapScope.countryRegion("Freedonia", cities: [a, b, other]))
        #expect(region.center.latitude == 11)
        #expect(region.center.longitude == 22)
        // 2 and 4 degrees apart: too small, so the minimum of 8 applies.
        #expect(region.span.latitudeDelta == 8)
        #expect(region.span.longitudeDelta == 8)
    }

    @Test func unknownCountryWithWideSpreadScalesAndCaps() throws {
        let a = city("A", country: "Freedonia", lat: 0, lon: 0)
        let b = city("B", country: "Freedonia", lat: 10, lon: 100)
        let region = try #require(MapScope.countryRegion("Freedonia", cities: [a, b]))
        #expect(abs(region.span.latitudeDelta - 14) < 0.0001)
        #expect(abs(region.span.longitudeDelta - 120) < 0.0001)
    }

    @Test func countryWithNoCitiesGivesNil() {
        #expect(MapScope.countryRegion("Freedonia", cities: []) == nil)
        let other = city("X", country: "Sylvania", lat: 1, lon: 1)
        #expect(MapScope.countryRegion("Freedonia", cities: [other]) == nil)
    }

    @Test func nearestCityPicksTheClosest() {
        let syd = city("Sydney", country: "Australia", lat: sydney.lat, lon: sydney.lon)
        let mel = city("Melbourne", country: "Australia", lat: melbourne.lat, lon: melbourne.lon)
        let point = CLLocationCoordinate2D(latitude: -36, longitude: 146)
        #expect(MapScope.nearestCity(to: point, in: [syd, mel])?.name == "Melbourne")
        #expect(MapScope.nearestCity(to: point, in: []) == nil)
    }

    @Test func focusCityWithin60kmIsHere() throws {
        let syd = city("Sydney", country: "Australia", lat: sydney.lat, lon: sydney.lon, daysLater: 0)
        let mel = city("Melbourne", country: "Australia", lat: melbourne.lat, lon: melbourne.lon, daysLater: 5)
        // About 10 km from Sydney.
        let here = CLLocation(latitude: sydney.lat + 0.09, longitude: sydney.lon)
        let focus = try #require(MapScope.focusCity(location: here, cities: [syd, mel]))
        #expect(focus.city.name == "Sydney")
        #expect(focus.isHere)
    }

    @Test func focusCityFarAwayUsesLatestCityNotHere() throws {
        let syd = city("Sydney", country: "Australia", lat: sydney.lat, lon: sydney.lon, daysLater: 0)
        let mel = city("Melbourne", country: "Australia", lat: melbourne.lat, lon: melbourne.lon, daysLater: 5)
        let london = CLLocation(latitude: 51.5, longitude: -0.12)
        let focus = try #require(MapScope.focusCity(location: london, cities: [syd, mel]))
        #expect(focus.city.name == "Melbourne")
        #expect(!focus.isHere)
    }

    @Test func focusCityWithoutLocationUsesLatestCity() throws {
        let syd = city("Sydney", country: "Australia", lat: sydney.lat, lon: sydney.lon, daysLater: 9)
        let mel = city("Melbourne", country: "Australia", lat: melbourne.lat, lon: melbourne.lon, daysLater: 5)
        let focus = try #require(MapScope.focusCity(location: nil, cities: [mel, syd]))
        #expect(focus.city.name == "Sydney")
        #expect(!focus.isHere)
    }

    @Test func focusCityWithNoCitiesIsNil() {
        #expect(MapScope.focusCity(location: nil, cities: []) == nil)
        #expect(MapScope.focusCity(location: CLLocation(latitude: 0, longitude: 0), cities: []) == nil)
    }
}
