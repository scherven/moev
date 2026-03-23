//
//  RecentSearchesStore.swift
//  moev
//
//  Created by Simon Chervenak on 3/23/26.
//


import Foundation

class RecentSearchesStore: ObservableObject {
    @Published var recents: [UIPlace] = []

    private let key = "recentSearches"
    private let maxRecents = 5

    init() {
        load()
    }

    func add(_ place: UIPlace) {
        recents.removeAll { $0.placeID == place.placeID }
        recents.insert(place, at: 0)
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([UIPlace].self, from: data) else { return }
        recents = saved
    }
}
