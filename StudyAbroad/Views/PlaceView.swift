import MapKit
import SwiftData
import SwiftUI

/// A place page: its rating, a small map, every visit there and the memories taken nearby.
/// Opened from the Ratings tab and from "Places you loved" on a city page.
struct PlaceView: View {
    let visit: Visit

    @Environment(MemoryStore.self) private var store
    @Environment(\.reviewVisit) private var reviewVisit
    @Query(filter: #Predicate<Visit> { $0.statusRaw == "saved" }) private var savedVisits: [Visit]
    /// Which memories the full-screen viewer is showing, and where it starts.
    @State private var playing: ViewerRequest?

    private var visitsHere: [Visit] { PlaceDetails.otherVisits(at: visit, among: savedVisits) }
    private var memoriesHere: [PhotoMemory] {
        PlaceDetails.memories(near: visit.coordinate, in: store.cities.flatMap(\.memories))
    }
    private var average: Double? { PlaceDetails.averageRating(of: visitsHere) }

    private var whereText: String {
        [visit.area, visit.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(visit.displayName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                if !whereText.isEmpty {
                    Text(whereText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                if let average {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(average, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.tint)
                        Text(RatingWords.describe(average))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 14)
                }

                Map(initialPosition: .region(MKCoordinateRegion(
                    center: visit.coordinate,
                    latitudinalMeters: 600,
                    longitudinalMeters: 600
                ))) {
                    Marker(visit.displayName, coordinate: visit.coordinate)
                }
                .allowsHitTesting(false)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 18)

                Text("Your visits")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .padding(.top, 26)
                    .padding(.bottom, 10)
                VStack(spacing: 10) {
                    ForEach(visitsHere) { item in
                        visitCard(item)
                    }
                }

                if !memoriesHere.isEmpty {
                    Text("Memories here")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 26)
                        .padding(.bottom, 10)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                        ForEach(memoriesHere) { memory in
                            Button { play(memory) } label: {
                                AssetThumbnail(memory: memory, side: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button { reviewVisit(visit) } label: {
                        Label("Rate again", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: openInMaps) {
                        Label("Open in Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(.top, 26)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playing) { request in
            MemoryViewer(title: visit.displayName, memories: request.memories, start: request.start)
        }
    }

    /// One visit: when, the rating and the recap.
    private func visitCard(_ item: Visit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.timeText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let rating = item.rating {
                    Text(rating, format: .number.precision(.fractionLength(1)))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
            }
            if !item.recap.isEmpty {
                Text(item.recap)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func play(_ memory: PhotoMemory) {
        playing = ViewerRequest(memories: memoriesHere, start: memory)
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: visit.coordinate))
        item.name = visit.displayName
        item.openInMaps()
    }
}
