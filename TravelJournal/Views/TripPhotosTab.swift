//
//  TripPhotosTab.swift
//  TravelJournal
//
//  Created by Gary Crook on 14/06/2026.
//

import SwiftUI

struct TripPhotosTab: View {
    let trip: Trip

    @State private var selectedPhoto: Photo?

    // All photos for this trip, in chronological order.
    // Uses trip.photos directly so photos without GPS (no visit) are included.
    private var photos: [Photo] {
        trip.photos.sorted { $0.datetime < $1.datetime }
    }

    // 3 equal columns with 1pt gaps — matches iOS Photos app grid layout.
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        Group {
            if photos.isEmpty {
                ContentUnavailableView(
                    "No Photos Yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Photos are imported from your assigned album.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(photos) { photo in
                            // Use a clear square as the layout anchor so every
                            // cell is exactly the same size regardless of image content.
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    PhotoKitThumbnail(
                                        assetIdentifier: photo.assetIdentifier,
                                        size: 150
                                    )
                                    .scaledToFill()
                                    .overlay(alignment: .topLeading) {
                                        if photo.isCoverPhoto {
                                            Image(systemName: "rectangle.portrait.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .padding(4)
                                                .background(DS.Color.primary.opacity(0.8))
                                                .clipShape(Circle())
                                                .padding(4)
                                        } else if photo.isFavourite {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.yellow)
                                                .padding(4)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        if !photo.isIncluded {
                                            Image(systemName: "eye.slash.fill")
                                                .font(.caption2)
                                                .padding(4)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                                }
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }
}
