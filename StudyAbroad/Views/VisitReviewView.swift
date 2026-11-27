import MapKit
import SwiftData
import SwiftUI

/// "You've been here" (from the Figma file): rate a place you just visited and add a quick recap.
/// Shows up as a sheet when the app opens and there's a visit waiting.
struct VisitReviewView: View {
    @Bindable var visit: Visit
    @Environment(MemoryStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 7.0
    @State private var recap = ""
    @FocusState private var recapFocused: Bool

    /// A photo you took during the visit, near the place, if there is one.
    private var visitPhoto: PhotoMemory? {
        let here = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
        let window = visit.arrival.addingTimeInterval(-10 * 60)...visit.departure.addingTimeInterval(10 * 60)
        return store.cities.lazy
            .flatMap(\.memories)
            .first { memory in
                guard let taken = memory.takenAt, window.contains(taken), memory.isPhoto else { return false }
                let spot = CLLocation(latitude: memory.coordinate.latitude, longitude: memory.coordinate.longitude)
                return spot.distance(from: here) < 300
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                card
                    .padding(.top, -24) // the white card overlaps the photo a little, as in the mockup
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.secondarySystemBackground))
        .onAppear {
            if let saved = visit.rating { rating = saved }
            recap = visit.recap
        }
    }

    // MARK: Top: "A new little chapter" + photo

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A new little chapter")
                .font(.title2.bold())
            Text([visit.city, Calendar.current.isDateInToday(visit.arrival) ? "Today" : nil]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Group {
                if let photo = visitPhoto {
                    GeometryReader { geo in
                        AssetThumbnail(memory: photo, width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    // No photo from this visit: show where it was instead.
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: visit.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                    )), interactionModes: []) {
                        Annotation(visit.displayName, coordinate: visit.coordinate) {
                            CityDot(name: "").frame(width: 44, height: 44)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .frame(height: 185)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    // MARK: The white card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 60, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("You’ve been here")
                .font(.largeTitle.bold())
                .padding(.top, 22)
            Text(visit.displayName)
                .font(.title2.bold())
                .padding(.top, 8)
            Text(visit.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("How was it?")
                .font(.headline)
                .padding(.top, 28)
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(rating, format: .number.precision(.fractionLength(1)))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(RatingWords.describe(rating))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
            Divider()
                .padding(.top, 8)
            Slider(value: $rating, in: 0...10, step: 0.1)
                .padding(.top, 14)
                .accessibilityValue(Text("\(rating, specifier: "%.1f") out of 10"))
            HStack {
                Text("Not for me")
                Spacer()
                Text("Loved it")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            TextField("A quick recap… what made it good (or not)?", text: $recap, axis: .vertical)
                .lineLimit(3...6)
                .focused($recapFocused)
                .padding(16)
                .frame(minHeight: 91, alignment: .topLeading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 20)

            Button(action: save) {
                Text("Save visit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, 26)

            Button("Not a visit", action: notAVisit)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    // MARK: Actions

    private func save() {
        visit.rating = (rating * 10).rounded() / 10
        visit.recap = recap.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.status = .saved
        try? context.save()
        dismiss()
    }

    private func notAVisit() {
        visit.status = .dismissed
        try? context.save()
        dismiss()
    }
}
