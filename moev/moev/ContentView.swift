//
//  ContentView.swift
//  moev
//
//  Created by Simon Chervenak on 11/27/23.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var selection: UUID?
    
    @State public var searching: Bool = false
    @State public var searchingFastAnimated: Bool = false
    @State public var searchingSlowAnimated: Bool = false
    
    @StateObject var locationManager = LocationManager()
    
    @State private var possibilities: [UIPlace] = []
        
    @State private var annotations: [Annotation] = [
        Annotation(id: 0, name: "", placeHolder: "Current location"),
        Annotation(id: 1, name: "")
    ]
    
    @State private var polylines: [UIPolyline] = []
    
    @State private var region = MKMapRect()
    
    @State private var searchingIdx = 0
    
    @State public var loadingResults: Bool = false
    @State public var showingResults: Bool = false

    @State private var routes: [UIRoutes] = []

    @State private var selectedMultiLeg: MultiLegRoute? = nil
    @State private var timePickerItem: TimePickerItem? = nil

    @StateObject private var recentSearches = RecentSearchesStore()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    map(geometry)
                        .frame(height: geometry.size.height / 2)
                    
                    recentsList()
                }
                
                VStack { // purple background that sweeps up
                    Text("")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(UIColor.Theme.searchColor)
                .frame(width: geometry.size.width,
                       height: searching ? geometry.size.height + 75 : 0)
                .offset(CGSize(width: 0.0, height: -75))
                .opacity(searchingFastAnimated ? 1 : 0)
                
                VStack { // list background that sweeps up after
                    RoundedRectangle(cornerRadius: 2.5)
                        .frame(width: 40, height: 5)
                        .foregroundColor(Color.gray.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    searchBars()
                        .padding(.horizontal, 10)

                    // Content area: possibilities sits on top of routes so
                    // you never see routes while picking a destination.
                    ZStack {
                        // Routes — bottom of the stack
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack {
                                timeMarks()
                                routesList()
                                    .scrollClipDisabled()
                            }
                        }
                        .opacity(showingResults ? 1 : 0)
                        .allowsHitTesting(showingResults)

                        // Loading spinner
                        ActivityIndicator(isAnimating: .constant(true), style: .large)
                            .opacity(loadingResults ? 1 : 0)
                            .allowsHitTesting(false)

                        // Suggestions — on top, fully covers routes.
                        // Mutually exclusive with showingResults: when routes
                        // are visible this is hidden, and tapping a search bar
                        // resets showingResults = false (in TextDisplay) which
                        // flips suggestions back on.
                        possibilitiesList()
                            .opacity(searchingSlowAnimated && !loadingResults && !showingResults ? 1 : 0)
                            .allowsHitTesting(searchingSlowAnimated && !loadingResults && !showingResults)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(UIColor.Theme.listBackgroundColor)
                .edgesIgnoringSafeArea(.all)
                .offset(CGSize(width: 0.0, height: searchingSlowAnimated ? 0 : geometry.size.height / 2 - 45))
                .frame(height: geometry.size.height - 30)
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.height > 100 {
                            dismissSearch()
                        }
                    }
                )
            }
            .sheet(item: $selectedMultiLeg) { multi in
                RouteDetailView(multiRoute: multi)
            }
        }
    }
    
    func dismissSearch() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.5)) {
            searchingSlowAnimated = false
        }
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            searchingFastAnimated = false
            searching = false
        }
    }

    func getDirections(senderID: Int) {
        print("[getDirections] senderID:", senderID, "annotations count:", annotations.count)
        withAnimation(Animation.easeInOut(duration: 0.5)) {
            loadingResults = true
        }

        if senderID > 0 {
            getDirections(id1: senderID - 1, id2: senderID)
        }

        if senderID < annotations.count - 1 {
            getDirections(id1: senderID, id2: senderID + 1)
        }
    }

    func getDirections(id1: Int, id2: Int) {
        let origin = getWaypoint(id1)
        let destination = getWaypoint(id2)
        print("[getDirections] id1:", id1, "id2:", id2,
              "origin:", origin != nil ? "ok" : "nil",
              "dest:", destination != nil ? "ok" : "nil")

        guard let o = origin, let d = destination else {
            print("[getDirections] missing waypoint, aborting")
            withAnimation(Animation.easeInOut(duration: 0.5)) {
                loadingResults = false
            }
            return
        }
        
//        updatePolylines(withID: id1, newPolyline: emptyPolyline())
        
        APIHandler.shared.directions(origin: o, destination: d, departureTime: annotations[id1].departureTime) { results, error in
            print("[getDirections] callback fired, results nil:", results == nil, "error:", error as Any)
            guard let route = results else {
                print("[getDirections] guard failed — no results, hiding spinner")
                withAnimation(Animation.easeInOut(duration: 0.5)) {
                    loadingResults = false
                }
                return
            }

            print("[getDirections] FOUND ROUTES", route.routes?.count as Any)
            updateRoutes(withID: id1, newRoute: route)

            withAnimation(Animation.easeInOut(duration: 0.5)) {
                loadingResults = false
                showingResults = true
            }
        }
    }
    
    func getWaypoint(_ id: Int) -> Waypoint? {
        var coord = annotations[id].location
        if coord == nil && id == 0 {
            coord = locationManager.lastLocation?.coordinate
        }
        return coord?.toWaypoint()
    }
    
    func updateRoutes(withID id: Int, newRoute: ComputeRoutesResponse) {
        if (newRoute.routes == nil) { return; }
        let r = combineRoutes(routes: newRoute.routes!)
        
        for i in routes.indices {
            if routes[i].id == id {
                routes[i].routes = r
                return
            }
        }
        routes.append(UIRoutes(id: id, routes: r))
    }
    
    func updatePolylines(withID id: Int, newPolyline: MKPolyline) {
        for i in polylines.indices {
            if polylines[i].id == id {
                polylines[i].polyline = newPolyline
                return
            }
        }
        polylines.append(UIPolyline(id: id, polyline: newPolyline))
    }
    
    
    func emptyPolyline() -> MKPolyline {
        return MKPolyline(coordinates: [], count: 0)
    }
    
    func map(_ geometry: GeometryProxy) -> some View {
        return Map {
            ForEach(annotations.filter { i in i.location != nil }) { a in
                Marker(coordinate: a.location!) {
                    Image(systemName: "mappin")
                }
            }
            
            ForEach(polylines) { p in
                MapPolyline(p.polyline)
                    .stroke(.blue, lineWidth: 2.0)
            }
            
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }
    
    func possibilitiesList() -> some View {
        return List(possibilities, selection: $selection) { place in
            HStack {
                Image(systemName: "mappin.and.ellipse")
                VStack(alignment: .leading) {
                    Text(place.main_text)
                        .font(.system(size: 17))
                        .lineLimit(1)
                    Text(place.secondary_text)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
            }
            .listRowBackground(UIColor.Theme.listBackgroundColor)
            .onTapGesture {
                addMarker(p: place)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    func timeMarks() -> some View {
        return HStack {
            ForEach(0..<6, id: \.self) { i in // todo calculate based on length of route
                Text(time(plus: i))
                    .position(x: CGFloat(xposition(for: time(plus: i))), y: 10)
            }
        }
    }
    
    @ViewBuilder
    func routesList() -> some View {
        // Collect the first alternative from each segment, ordered by id (A→B, B→C …)
        let ordered = routes.sorted { $0.id < $1.id }
        let firstRoutes = ordered.compactMap { $0.routes.first }

        if !firstRoutes.isEmpty {
            // Build dwell array: dwellMinutes[i] = time spent at the stop
            // between segments[i] and segments[i+1], i.e. annotations[i+1].
            let dwell: [Int?] = firstRoutes.indices.map { i in
                i + 1 < annotations.count ? annotations[i + 1].dwellMinutes : nil
            }

            let multi = MultiLegRoute(segments: firstRoutes, dwellMinutes: dwell)

            MultiRouteView(multiRoute: multi) {
                selectedMultiLeg = multi
            }
        }
    }
    
    func recentsList() -> some View {
        List(recentSearches.recents) { place in
            HStack {
                Image(systemName: "clock")
                VStack(alignment: .leading) {
                    Text(place.main_text)
                        .font(.system(size: 17))
                        .lineLimit(1)
                    Text(place.secondary_text)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
            }
            .listRowBackground(UIColor.Theme.listBackgroundColor)
            .onTapGesture {
                addMarker(p: place)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(UIColor.Theme.listBackgroundColor)
    }

    func renumberAnnotations() {
        for i in annotations.indices {
            annotations[i].id = i
        }
    }

    func addMarker(p: UIPlace) {
        APIHandler.shared.get_info(place_id: p.placeID) { result, error in
            guard let result = result else { return }

            annotations[searchingIdx].name = result.name
            annotations[searchingIdx].location = result.location
            annotations[searchingIdx].placeID = p.placeID
            annotations[searchingIdx].justChanged = true

            recentSearches.add(p)
            getDirections(senderID: searchingIdx)
        }
    }
    
    func searchBars() -> some View {
        VStack(spacing: 0) {
            ForEach(annotations.indices, id: \.self) { i in
                HStack {
                    TextDisplay(annotation: $annotations[i],
                                searching: $searching,
                                searchingFastAnimated: $searchingFastAnimated,
                                searchingSlowAnimated: $searchingSlowAnimated,
                                possibilities: $possibilities,
                                searchingIdx: $searchingIdx,
                                showingResults: $showingResults,
                                location: locationManager.lastLocation,
                                getDirections: getDirections)
                    Button {
                        timePickerItem = TimePickerItem(id: i)
                    } label: {
                        let isSet = i == 0
                            ? annotations[i].departureTime != nil
                            : annotations[i].dwellMinutes != nil
                        Image(systemName: isSet ? "clock.fill" : "clock")
                            .padding(8)
                            .foregroundColor(isSet ? UIColor.Theme.searchColor : .secondary)
                    }
                    Button {
                        annotations.insert(Annotation(id: 0, name: ""), at: i + 1)
                        renumberAnnotations()
                    } label: {
                        Image(systemName: "plus.circle")
                            .padding(8)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(item: $timePickerItem) { item in
            if item.id == 0 {
                // Origin: pick a departure time
                VStack(spacing: 16) {
                    HStack {
                        Button("Clear") {
                            annotations[item.id].departureTime = nil
                            timePickerItem = nil
                        }
                        Spacer()
                        Text("Depart at").font(.headline)
                        Spacer()
                        Button("Done") { timePickerItem = nil }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { annotations[item.id].departureTime ?? Date() },
                            set: { annotations[item.id].departureTime = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal)

                    Spacer()
                }
                .presentationDetents([.height(320)])
            } else {
                // Intermediate / destination: pick dwell time in minutes
                VStack(spacing: 16) {
                    HStack {
                        Button("Clear") {
                            annotations[item.id].dwellMinutes = nil
                            timePickerItem = nil
                        }
                        Spacer()
                        Text("Time at stop").font(.headline)
                        Spacer()
                        Button("Done") { timePickerItem = nil }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Picker("Minutes", selection: Binding(
                        get: { annotations[item.id].dwellMinutes ?? 15 },
                        set: { annotations[item.id].dwellMinutes = $0 }
                    )) {
                        ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { m in
                            Text(m < 60 ? "\(m) min" : "\(m / 60) hr \(m % 60 == 0 ? "" : "\(m % 60) min")")
                                .tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .padding(.horizontal)

                    Spacer()
                }
                .presentationDetents([.height(280)])
            }
        }
    }
}

#Preview {
    ContentView()
}
