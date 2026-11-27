import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

/// "Find a city": ranking, accents/capitals, caption matches and snippets.
struct CitySearchTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func memory(_ id: String, daysLater: Double) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
                    takenAt: base.addingTimeInterval(daysLater * 86_400), isVideo: false)
    }

    private func city(_ name: String, country: String? = "Australia", ids: [String], daysLater: Double = 0) -> CityCluster {
        CityCluster(id: "\(name)|\(country ?? "")", name: name, country: country,
                    center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
                    memories: ids.map { memory($0, daysLater: daysLater) })
    }

    @Test func emptyQueryListsEveryCityNewestFirst() {
        let old = city("Perth", ids: ["p1"], daysLater: 0)
        let new = city("Hobart", ids: ["h1"], daysLater: 10)
        let results = CitySearch.search("", in: [old, new], captions: [:])
        #expect(results.map(\.city.name) == ["Hobart", "Perth"])
        #expect(results.allSatisfy { $0.snippet == nil })
        #expect(CitySearch.search("   ", in: [old, new], captions: [:]).count == 2)
    }

    @Test func noCitiesGivesNoResults() {
        #expect(CitySearch.search("x", in: [], captions: [:]).isEmpty)
        #expect(CitySearch.search("", in: [], captions: [:]).isEmpty)
    }

    @Test func prefixBeatsContainsBeatsCountryBeatsCaption() {
        let byCaption = city("Alpha", country: "Nowhere", ids: ["cap"])
        let byCountry = city("Beta", country: "Sydlandia", ids: ["b"])
        let byContains = city("New Sydney", country: "Nowhere", ids: ["c"])
        let byPrefix = city("Sydney", country: "Nowhere", ids: ["d"])
        let results = CitySearch.search("syd", in: [byCaption, byCountry, byContains, byPrefix],
                                        captions: ["cap": "Lunch near syd harbour"])
        #expect(results.map(\.city.name) == ["Sydney", "New Sydney", "Beta", "Alpha"])
    }

    @Test func ignoresCapitalsAndAccents() {
        let c = city("Zürich", country: "Switzerland", ids: ["z"])
        #expect(CitySearch.search("zurich", in: [c], captions: [:]).count == 1)
        #expect(CitySearch.search("ZÜR", in: [c], captions: [:]).count == 1)
        #expect(CitySearch.search("switz", in: [c], captions: [:]).count == 1)
    }

    @Test func captionMatchReturnsSnippet() {
        let c = city("Cairns", ids: ["m1"])
        let results = CitySearch.search("reef", in: [c], captions: ["m1": "Snorkelling the Reef!"])
        #expect(results.count == 1)
        #expect(results.first?.snippet == "Snorkelling the Reef!")
    }

    @Test func nameMatchHasNoSnippet() {
        let c = city("Cairns", ids: ["m1"])
        let results = CitySearch.search("cairns", in: [c], captions: ["m1": "cairns again"])
        #expect(results.first?.snippet == nil)
    }

    @Test func captionsForMemoriesNotInACityDoNotMatch() {
        let c = city("Cairns", ids: ["m1"])
        let results = CitySearch.search("secret", in: [c], captions: ["removed": "secret beach"])
        #expect(results.isEmpty)
    }

    @Test func cityWithNoCountryStillSearchable() {
        let c = city("Atlantis", country: nil, ids: ["a"])
        #expect(CitySearch.search("atl", in: [c], captions: [:]).count == 1)
        #expect(CitySearch.search("nothing", in: [c], captions: [:]).isEmpty)
    }

    @Test func sameRankSortsByMemoryCount() {
        let small = city("Portland", country: "A", ids: ["s1"])
        let big = city("Port Douglas", country: "B", ids: ["b1", "b2", "b3"])
        let results = CitySearch.search("port", in: [small, big], captions: [:])
        #expect(results.map(\.city.name) == ["Port Douglas", "Portland"])
    }

    @Test func shortCaptionSnippetIsWholeCaptionOnOneLine() {
        #expect(CitySearch.snippet(of: "line one\nline two", around: "two") == "line one line two")
    }

    @Test func longCaptionSnippetIsTrimmedAroundTheMatch() {
        let caption = String(repeating: "a", count: 50) + " needle " + String(repeating: "b", count: 50)
        let snippet = CitySearch.snippet(of: caption, around: "needle")
        #expect(snippet.contains("needle"))
        #expect(snippet.hasPrefix("…"))
        #expect(snippet.hasSuffix("…"))
        // 60 characters plus the two ellipses.
        #expect(snippet.count == 62)
    }

    @Test func longCaptionMatchedAtTheStartHasNoLeadingEllipsis() {
        let caption = "needle " + String(repeating: "x", count: 100)
        let snippet = CitySearch.snippet(of: caption, around: "needle")
        #expect(!snippet.hasPrefix("…"))
        #expect(snippet.hasSuffix("…"))
        #expect(snippet.hasPrefix("needle"))
    }
}
