import Foundation
import SwiftData
import CoreLocation
import MapKit

// GPSClusteringService
//
// Groups a trip's imported photos into spatial clusters and creates a
// Location + Visit record for each one. Photos that have no GPS data
// are silently skipped and can be assigned manually later.
//
// Algorithm: greedy temporal-spatial clustering.
//   - Sort photos by timestamp.
//   - Add each photo to the current cluster if it is within
//     distanceThresholdMeters of the cluster's running centroid AND
//     the time gap since the previous photo is within timeGapThresholdSeconds.
//   - Otherwise start a new cluster.
//
// After clustering, each cluster's centroid is reverse-geocoded to
// produce a suggested location name, city, and country.

@Observable
class GPSClusteringService {

    var isRunning = false
    var status = ""

    // ── Tuning parameters ────────────────────────────────────────────────────
    // Photos within 500 m of the cluster centroid belong to the same location.
    static let distanceThresholdMeters: Double = 500
    // A gap of more than 2 hours between consecutive photos starts a new cluster
    // even if the two photos are close together (e.g. returning to the same café).
    static let timeGapThresholdSeconds: Double = 7200

    // ── Public entry point ───────────────────────────────────────────────────

    @MainActor
    func clusterPhotos(for trip: Trip, context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        status = "Reading photo locations…"

        // 1. Collect photos that have GPS and have not already been clustered.
        //    GPS is stored in photo.metadata as JSON: {"latitude": 0.0, "longitude": 0.0}
        let gpsPhotos: [(photo: Photo, lat: Double, lng: Double)] = trip.photos
            .filter { $0.visit == nil }
            .compactMap { photo -> (photo: Photo, lat: Double, lng: Double)? in
                guard
                    let data = photo.metadata,
                    let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let lat = (dict["latitude"] as? NSNumber)?.doubleValue,
                    let lng = (dict["longitude"] as? NSNumber)?.doubleValue
                else { return nil }
                return (photo, lat, lng)
            }
            .sorted { $0.photo.datetime < $1.photo.datetime }

        guard !gpsPhotos.isEmpty else {
            status = "No unprocessed photos with GPS data found."
            isRunning = false
            return
        }

        // 2. Greedy clustering ────────────────────────────────────────────────

        // A Cluster holds its member photos and a running centroid (mean lat/lng).
        struct Cluster {
            var photos: [(photo: Photo, lat: Double, lng: Double)]
            var centroidLat: Double
            var centroidLng: Double

            var centroid: CLLocation {
                CLLocation(latitude: centroidLat, longitude: centroidLng)
            }
            var earliestDate: Date {
                photos.map { $0.photo.datetime }.min() ?? .now
            }

            mutating func add(photo: Photo, lat: Double, lng: Double) {
                photos.append((photo, lat, lng))
                let n = Double(photos.count)
                centroidLat = photos.reduce(0) { $0 + $1.lat } / n
                centroidLng = photos.reduce(0) { $0 + $1.lng } / n
            }
        }

        var clusters: [Cluster] = []

        for item in gpsPhotos {
            let itemCLLocation = CLLocation(latitude: item.lat, longitude: item.lng)

            if !clusters.isEmpty {
                let lastCluster = clusters[clusters.count - 1]
                let lastPhoto = lastCluster.photos.last!
                let distance = lastCluster.centroid.distance(from: itemCLLocation)
                let timeGap = item.photo.datetime.timeIntervalSince(lastPhoto.photo.datetime)

                if distance <= Self.distanceThresholdMeters,
                   timeGap <= Self.timeGapThresholdSeconds {
                    clusters[clusters.count - 1].add(photo: item.photo, lat: item.lat, lng: item.lng)
                    continue
                }
            }

            // Start a new cluster for this photo.
            clusters.append(Cluster(
                photos: [(item.photo, item.lat, item.lng)],
                centroidLat: item.lat,
                centroidLng: item.lng
            ))
        }

        let total = clusters.count
        status = "Found \(total) location\(total == 1 ? "" : "s"). Naming them…"

        // 3. Reverse geocode each centroid and create model objects ───────────
        //
        // MKReverseGeocodingRequest replaces the deprecated CLGeocoder.
        // The initializer returns an optional (nil for invalid coordinates).
        // `request.mapItems` is async throws — unwrap with try? await.
        // Rate-limit to ~1 request per second.

        for (index, cluster) in clusters.enumerated() {
            status = "Naming location \(index + 1) of \(total)…"

            var name = "Location \(index + 1)"
            var city = ""
            var country = ""

            if let request = MKReverseGeocodingRequest(location: cluster.centroid),
               let mapItems = try? await request.mapItems,
               let mapItem = mapItems.first {
                let rawName = mapItem.name ?? ""
                city        = mapItem.addressRepresentations?.cityWithContext ?? ""
                country     = ""   // no structured country field in iOS 26/27

                // mapItem.name can be a POI name ("The High Line") or a street
                // address ("20 Commerce St"). Street addresses start with a digit.
                // When it's a street address, fall back to the city name so the
                // journal reads "New York" rather than "20 Commerce St".
                // MKAddressRepresentations doesn't expose subLocality in iOS 26/27
                // and MKMapItem.placemark is deprecated — city is the safest fallback.
                let isStreetAddress = rawName.first?.isNumber ?? false
                if isStreetAddress {
                    name = city.isEmpty ? rawName : city
                } else {
                    name = rawName.isEmpty ? "Location \(index + 1)" : rawName
                }
            }

            // Create Location record.
            let location = Location(
                name: name,
                city: city,
                country: country,
                latitude: cluster.centroidLat,
                longitude: cluster.centroidLng
            )
            context.insert(location)

            // Create Visit — one per cluster. datetime = earliest photo in cluster.
            // The visit has no album because it was derived from clustering, not from
            // manual album assignment. That is fine: album is optional on Visit.
            let visit = Visit(datetime: cluster.earliestDate)
            visit.trip = trip
            visit.location = location
            context.insert(visit)

            // Link each photo to this location and visit.
            for item in cluster.photos {
                item.photo.location = location
                item.photo.visit = visit
            }

            // Rate-limit geocoder calls — skip delay after the last one.
            if index < total - 1 {
                try? await Task.sleep(for: .seconds(1.1))
            }
        }

        try? context.save()
        status = "\(total) location\(total == 1 ? "" : "s") created."
        isRunning = false
    }
}
