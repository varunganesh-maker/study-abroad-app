import CoreLocation
import SwiftData
import SwiftUI

/// "Your ratings" (from the Figma file): visits waiting for a rating (so a missed notification
/// isn't lost), then every place you've rated, newest first. ＋ is "I was here" for places the
/// phone didn't notice.
struct RatingsView: View {
    @Environment(VisitMonitor.self) private var visits
    @Environment(\.modelContext) private var context
    @Environment(\.reviewVisit) private var reviewVisit
    @Query(filter: #Predicate<Visit> { $0.statusRaw == "pending" && $0.placeName != "" },
           sort: \Visit.arrival, order: .reverse)
    private var waiting: [Visit]
    @Query(filter: #Predicate<Visit> { $0.statusRaw == "saved" }, sort: \Visit.arrival, order: .reverse)
    private var rated: [Visit]

    @State private var location = LocationProvider()
    @State private var capturing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if !waiting.isEmpty {
                    Section {
                        ForEach(waiting) { visit in
                            Button { reviewVisit(visit) } label: {
                                VisitRow(visit: visit, trailing: "Rate")
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Waiting for a rating · \(waiting.count)")
                    }
                }

                Section {
                    if rated.isEmpty {
                        Text("Places you rate show up here. Visits are noticed on their own when location is set to Always, or tap ＋ when you're somewhere worth remembering.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rated) { visit in
                        NavigationLink {
                            PlaceView(visit: visit)
                        } label: {
                            VisitRow(visit: visit, trailing: visit.rating.map { $0.formatted(.number.precision(.fractionLength(1))) },
                                     showsChevron: false)
                        }
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("Recently remembered")
                }
            }
            .listStyle(.insetGrouped)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $capturing) {
                CaptureView()
            }
            .task { location.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Your ratings")
                    .font(.largeTitle.bold())
                Spacer()
                Button(action: iWasHere) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .accessibilityLabel("I was here")
                .accessibilityIdentifier("iWasHereButton")
            }
            Text("Places, people & everything in between")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Button { capturing = true } label: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Something worth remembering?")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Capture, upload, write or speak   →")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .padding(.vertical, 8)
    }

    /// "I was here": rate the place you're at right now.
    private func iWasHere() {
        let status = CLLocationManager().authorizationStatus
        guard status != .denied && status != .restricted else {
            message = "Location is off for Study Abroad. Turn it on in Settings › Study Abroad › Location."
            return
        }
        guard let here = location.location else {
            location.refresh()
            message = "Finding where you are… turn on Location Services for Study Abroad if this doesn't work, then tap ＋ again."
            return
        }
        message = nil
        // The rating sheet opens on its own (the app shows any visit waiting for a rating).
        visits.record(coordinate: here.coordinate, arrival: .now.addingTimeInterval(-30 * 60), departure: .now, manual: true)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(rated[index]) }
        try? context.save()
    }
}

/// One place in the list: name, where and when, and the rating (or "Rate").
private struct VisitRow: View {
    let visit: Visit
    let trailing: String?
    /// Off inside a NavigationLink, which draws its own arrow.
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(visit.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !visit.recap.isEmpty {
                    Text(visit.recap)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.tint)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    /// "Surry Hills · 24 February"
    private var details: String {
        [visit.area ?? visit.city, visit.arrival.formatted(.dateTime.day().month(.wide))]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
