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

                    possibilitiesList()
                    .offset(CGSize(width: 0.0, height: 5))
                    .opacity(searchingSlowAnimated && !(loadingResults || showingResults) ? 1 : 0)

                    ActivityIndicator(isAnimating: .constant(true), style: .large)
                    .offset(CGSize(width: 0.0, height: -geometry.size.height / 2))
                    .opacity(loadingResults ? 1 : 0)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack {
                            timeMarks()
                            routesList()
                                .scrollClipDisabled()
                        }
                    }
                    .offset(CGSize(width: 0.0, height: -geometry.size.height / 2))
                    .opacity(showingResults ? 1 : 0)
                }
                .background(UIColor.Theme.listBackgroundColor)
                .edgesIgnoringSafeArea(.all)
                .offset(CGSize(width: 0.0, height: searchingSlowAnimated ? 0 : geometry.size.height))
                .frame(height: geometry.size.height - 30)
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.height > 100 {
                            dismissSearch()
                        }
                    }
                )
                
                VStack {
                    searchBars()
                    Spacer()
                }
                .offset(CGSize(width: 10.0, height: searching ? 0 : geometry.size.height / 2 - 20))
            }
        }
    }
    
    func dismissSearch() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.5)) {
            searchingSlowAnimated = false
        }
        withAnimation(.easeInOut(duration: 0.2).delay(0.3)) {
            searchingFastAnimated = false
            searching = false
        }
    }

    func getDirections(senderID: Int) {
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
        
        guard let o = origin, let d = destination else {
            return // todo
        }
        
//        updatePolylines(withID: id1, newPolyline: emptyPolyline())
        
        APIHandler.shared.directions(origin: o, destination: d) { results, error in
            guard let route = results else {
                print("e", error)
                return
            }
            
            print("FOUND ROUTES", route.routes?.count)
            
//            print("GOT ROUTE", route)
            
//            let polyline = route.polyline.decode()
//            updatePolylines(withID: id1, newPolyline: polyline)
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
    
    func routesList() -> some View {
        return ForEach(routes) { rs in
            ForEach(rs.routes) { route in
                RouteView(route: route)
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
        // todo expand or something
//        return ForEach($annotations) { $a in
//            TextDisplay(annotation: $a, 
//                        searching: $searching,
//                        searchingFastAnimated: $searchingFastAnimated,
//                        searchingSlowAnimated: $searchingSlowAnimated,
//                        possibilities: $possibilities,
//                        getDirections: getDirections)
//        }
        return HStack {
            TextDisplay(annotation: $annotations[1],
                        searching: $searching,
                        searchingFastAnimated: $searchingFastAnimated,
                        searchingSlowAnimated: $searchingSlowAnimated,
                        possibilities: $possibilities,
                        searchingIdx: $searchingIdx,
                        location: locationManager.lastLocation,
                        getDirections: getDirections)
        }
    }
}

#Preview {
    ContentView()
}
