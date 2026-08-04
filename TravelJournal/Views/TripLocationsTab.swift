import SwiftUI
import MapKit

// MARK: - VisitRowView

struct VisitRowView: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(visit.datetime.formatted(date: .abbreviated, time: .omitted))
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.primary)
                if !visit.weather.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cloud.sun")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.secondary)
                        Text(visit.weather)
                            .font(DS.Font.label)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                if !visit.reason.isEmpty {
                    Text(visit.reason)
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            Spacer()
            if visit.photos.count > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "photo")
                        .font(.system(size: 11))
                    Text("\(visit.photos.count)")
                        .font(DS.Font.label)
                }
                .foregroundStyle(DS.Color.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
    }
}

// MARK: - TripLocationsTab

struct TripLocationsTab: View {
    let trip: Trip

    @State private var selectedLocation: Location?
    @Namespace private var scrollNamespace

    // Unique locations from visits, in chronological order of first visit
    private var locations: [Location] {
        var seen: Set<ObjectIdentifier> = []
        return trip.visits
            .sorted { $0.datetime < $1.datetime }
            .compactMap { $0.location }
            .filter { seen.insert(ObjectIdentifier($0)).inserted }
    }

    // MapKit camera region fitting all location pins
    private var mapRegion: MKCoordinateRegion {
        guard !locations.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        let lats = locations.map { $0.latitude }
        let lons = locations.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let centre = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.05)
        )
        return MKCoordinateRegion(center: centre, span: span)
    }

    var body: some View {
        Group {
            if locations.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // ── Map ──────────────────────────────────────────
                            mapView
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                                .padding(.horizontal, DS.Spacing.screen)
                                .padding(.top, DS.Spacing.md)
                                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)

                            // ── Location cards ───────────────────────────────
                            VStack(spacing: DS.Spacing.md) {
                                ForEach(locations) { location in
                                    locationCard(for: location)
                                        .id(location.id)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.medium)
                                                .stroke(
                                                    selectedLocation?.id == location.id
                                                        ? DS.Color.primary : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screen)
                            .padding(.vertical, DS.Spacing.md)
                        }
                    }
                    .background(DS.Color.surface.ignoresSafeArea())
                    .onChange(of: selectedLocation) { _, newLocation in
                        if let loc = newLocation {
                            withAnimation {
                                proxy.scrollTo(loc.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(initialPosition: .region(mapRegion)) {
            ForEach(locations) { location in
                Annotation(
                    location.name,
                    coordinate: location.coordinate,
                    anchor: .bottom
                ) {
                    Button {
                        withAnimation {
                            selectedLocation = location
                        }
                    } label: {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle()
                                    .fill(selectedLocation?.id == location.id
                                          ? DS.Color.primary : .white)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                Image(systemName: "mappin.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(selectedLocation?.id == location.id
                                                     ? .white : DS.Color.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Location card

    @ViewBuilder
    private func locationCard(for location: Location) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(DS.Font.title2)
                        .foregroundStyle(DS.Color.primary)
                    if !location.city.isEmpty {
                        Text(location.city)
                            .font(DS.Font.label)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                Spacer()
                // Mini coordinate badge
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.4f°", location.latitude))
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.secondary)
                    Text(String(format: "%.4f°", location.longitude))
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            .padding(.bottom, DS.Spacing.xs)

            Divider().background(DS.Color.border)

            let locationVisits = trip.visits
                .filter { $0.location === location }
                .sorted { $0.datetime < $1.datetime }

            VStack(spacing: DS.Spacing.sm) {
                ForEach(locationVisits) { visit in
                    VisitRowView(visit: visit)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .onTapGesture {
            withAnimation { selectedLocation = location }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.secondary)
            Text("No Locations Yet")
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.primary)
            Text("Locations are created automatically when photos are imported.")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
        .background(DS.Color.surface.ignoresSafeArea())
    }
}
