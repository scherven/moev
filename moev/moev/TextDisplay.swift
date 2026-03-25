//
//  TextDisplay.swift
//  moev
//
//  Created by Simon Chervenak on 11/28/23.
//

import SwiftUI
import MapKit

struct TextDisplay: View {
    @Binding public var annotation: Annotation
    @Binding public var searching: Bool
    @Binding public var searchingFastAnimated: Bool
    @Binding public var searchingSlowAnimated: Bool
    @Binding public var possibilities: [UIPlace]
    @Binding public var searchingIdx: Int
    @Binding public var showingResults: Bool

    public var location: CLLocation?
    public var getDirections: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .padding(.leading, 12)
                .opacity(searchingSlowAnimated ? 1 : 0)
            TextField(annotation.placeHolder, text: $annotation.name, onEditingChanged: { isEditing in
                withAnimation(Animation.easeInOut(duration: 0.5)) {
                    searching = true
                }
                withAnimation(Animation.easeInOut(duration: 0.2)) {
                    searchingFastAnimated = true
                }
                withAnimation(Animation.easeInOut(duration: 0.5).delay(0.3)) {
                    searchingSlowAnimated = true
                }
                searchingIdx = annotation.id
                if isEditing { showingResults = false }
                if isEditing && annotation.name.isEmpty {
                    fetchNearby()
                }
            })
            .onChange(of: annotation.name) { o, n in
                if annotation.justChanged {
                    annotation.justChanged = false
                } else {
                    updatePossibilities()
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
        .background(UIColor.Theme.searchColor)
        .cornerRadius(8)
    }

    func updatePossibilities() {
        APIHandler.shared.autocomplete(query: annotation.name) { places, error in
            guard let places = places else { return }
            possibilities = places
        }
    }

    func fetchNearby() {
        guard let coord = location?.coordinate else { return }
        APIHandler.shared.fetchNearby(coordinate: coord) { places, error in
            guard let places = places else { return }
            possibilities = places
        }
    }
}
