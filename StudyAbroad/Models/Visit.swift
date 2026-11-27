import CoreLocation
import Foundation
import SwiftData

/// A place the phone stayed at for a while (detected by iOS), plus Varun's rating and recap.
/// Saved on the phone with SwiftData (Apple's built-in database).
@Model
final class Visit {
    enum Status: String, Codable {
        /// Detected, waiting for "How was it?"
        case pending
        /// Rated and kept.
        case saved
        /// "Not a visit" (e.g. waiting at a bus stop).
        case dismissed
    }

    var latitude: Double
    var longitude: Double
    var arrival: Date
    var departure: Date
    /// "AP Bakery". Empty until the place has been looked up.
    var placeName: String = ""
    /// Suburb or neighbourhood, e.g. "Surry Hills".
    var area: String?
    /// City, e.g. "Sydney" (matches the city names on the map).
    var city: String?
    /// 0 to 10, one decimal place. Nil until rated.
    var rating: Double?
    var recap: String = ""
    var statusRaw: String = Status.pending.rawValue

    init(coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.arrival = arrival
        self.departure = departure
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String { placeName.isEmpty ? "Somewhere new" : placeName }

    /// "Today, 9:12–10:06 am" / "Mon 24 Feb, 9:12–10:06 am"
    var timeText: String {
        let day: String
        if Calendar.current.isDateInToday(arrival) {
            day = "Today"
        } else if Calendar.current.isDateInYesterday(arrival) {
            day = "Yesterday"
        } else {
            day = arrival.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        let start = arrival.formatted(date: .omitted, time: .shortened)
        let end = departure.formatted(date: .omitted, time: .shortened)
        return "\(day), \(start)–\(end)"
    }

    /// "Surry Hills · Today, 9:12–10:06 am"
    var subtitle: String {
        [area, timeText].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Words that go with a rating, shown next to the number.
enum RatingWords {
    static func describe(_ rating: Double) -> String {
        switch rating {
        case ..<3: "Not for me"
        case ..<5: "Meh"
        case ..<6.5: "It was fine"
        case ..<7.5: "Pretty good"
        case ..<8.5: "Really liked it"
        default: "A new favourite"
        }
    }
}
