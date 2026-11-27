import MapKit
import SwiftUI

/// "Tap to change" on the New moment screen: move the map until the pin sits on the right spot.
struct LocationPickerView: View {
    let start: CLLocationCoordinate2D?
    let onPick: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?

    init(start: CLLocationCoordinate2D?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.start = start
        self.onPick = onPick
        if let start {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: start, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
        } else {
            _position = State(initialValue: .region(MapScope.worldRegion(centeredOn: nil)))
        }
        _center = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) { UserAnnotation() }
                .mapStyle(.standard)
                .onMapCameraChange(frequency: .continuous) { context in
                    center = context.region.center
                }
                .overlay {
                    // The pin stays in the middle; the map moves under it.
                    Image(systemName: "mappin")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.tint)
                        .offset(y: -20)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .top) {
                    Text("Move the map to put the pin where it happened")
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 10)
                }
                .navigationTitle("Choose place")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use this place") {
                            if let center { onPick(center) }
                            dismiss()
                        }
                        .bold()
                        .disabled(center == nil)
                    }
                }
        }
    }
}
