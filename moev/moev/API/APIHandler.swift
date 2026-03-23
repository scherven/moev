//
//  APIHandler.swift
//  moev
//
//  Created by Simon Chervenak on 11/27/23.
//

import Foundation
import CoreLocation
import MapKit

typealias RequestHandler = (Data?, URLResponse?, Error?) -> Void

struct PlaceResult {
    var name: String
    var location: CLLocationCoordinate2D
}

class APIHandler {
    static let shared = APIHandler()
    
    let GMAK: String
    
    var session: UUID? = nil
    
    init() {
        GMAK = Bundle.main.infoDictionary!["GOOGLE_MAPS_API_KEY"] as! String
    }
    
    func _request(url: String, headers: [String: String], body: Encodable?, method: String, handler: @escaping RequestHandler) {
        do {
            let url = URL(string: url)!
            var request = URLRequest(url: url)
            for (header, value) in headers {
                request.setValue(value, forHTTPHeaderField: header)
            }
            request.httpMethod = method
            let encoder = JSONEncoder()
            
            if let b = body {
                let data = try encoder.encode(b)
                request.httpBody = data
            }

            let task = URLSession.shared.dataTask(with: request, completionHandler: handler)
            task.resume()
        } catch {
            
        }
    }
    
    func _get_request(baseurl: String, params: [String: String], headers: [String: String] = [:], handler: @escaping RequestHandler) {
        guard var components = URLComponents(string: baseurl) else { return }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { return }
        _request(url: url.absoluteString, headers: headers, body: nil, method: "GET", handler: handler)
    }
    
    func fetchNearby(coordinate: CLLocationCoordinate2D, handler: @escaping ([UIPlace]?, Error?) -> Void) {
        struct Center: Encodable { let latitude: Double; let longitude: Double }
        struct Circle: Encodable { let center: Center; let radius: Double }
        struct LocationRestriction: Encodable { let circle: Circle }
        struct NearbyRequest: Encodable {
            let maxResultCount: Int
            let rankPreference: String
            let locationRestriction: LocationRestriction
        }

        let body = NearbyRequest(
            maxResultCount: 10,
            rankPreference: "DISTANCE",
            locationRestriction: LocationRestriction(
                circle: Circle(
                    center: Center(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    radius: 1000.0
                )
            )
        )

        let headers: [String: String] = [
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GMAK,
            "X-Goog-FieldMask": "places.id,places.displayName,places.formattedAddress"
        ]

        _request(url: "https://places.googleapis.com/v1/places:searchNearby",
                 headers: headers,
                 body: body,
                 method: "POST") { data, _, error in
            guard let d = data,
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let places = json["places"] as? [[String: Any]] else {
                return handler(nil, error)
            }

            let results: [UIPlace] = places.compactMap { place in
                guard let name = (place["displayName"] as? [String: Any])?["text"] as? String,
                      let id = place["id"] as? String else { return nil }
                let address = place["formattedAddress"] as? String ?? ""
                return UIPlace(main_text: name, secondary_text: address, placeID: id)
            }

            handler(results, nil)
        }
    }
    
    func directions(origin: Waypoint, destination: Waypoint, handler: @escaping(ComputeRoutesResponse?, Error?) -> Void) {
        let url = "https://routes.googleapis.com/directions/v2:computeRoutes"
        
        let body = ComputeRoutesRequest(
            origin: origin,
            destination: destination,
            travelMode: .TRANSIT,
            polylineEncoding: .ENCODED_POLYLINE,
            computeAlternativeRoutes: true
        )
        
        let fields = [
            "routes.duration",
            "routes.distanceMeters",
            "routes.polyline.encodedPolyline",
            "routes.description",
            "routes.legs",
            "routes.travelAdvisory",
            "routes.viewport",
            "routes.localizedValues"
        ]
        
        let headers: [String: String] = [
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GMAK,
            "X-Goog-FieldMask": fields.joined(separator: ",")
        ]
        
        _request(url: url, headers: headers, body: body, method: "POST") { data, response, error in
            guard let d = data else {
                return handler(nil, error)
            }
            
            let results = ComputeRoutesResponse.from(jsonData: d)
            
            handler(results, error)
        }
    }
    
    func start_session() {
        session = UUID()
    }
    
    private struct AutocompleteRequest: Encodable {
        let input: String
        let sessionToken: String
    }

    func autocomplete(query: String, handler: @escaping ([UIPlace]?, Error?) -> Void) {
        if session == nil {
            start_session()
        }

        let body = AutocompleteRequest(input: query, sessionToken: session!.uuidString)
        let headers: [String: String] = [
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GMAK
        ]

        _request(url: "https://places.googleapis.com/v1/places:autocomplete",
                 headers: headers,
                 body: body,
                 method: "POST") { data, response, error in
            guard let d = data,
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let suggestions = json["suggestions"] as? [[String: Any]] else {
                return handler(nil, error)
            }

            let places: [UIPlace] = suggestions.compactMap { suggestion in
                guard let pred = suggestion["placePrediction"] as? [String: Any],
                      let placeId = pred["placeId"] as? String,
                      let sf = pred["structuredFormat"] as? [String: Any],
                      let mainText = (sf["mainText"] as? [String: Any])?["text"] as? String,
                      let secondaryText = (sf["secondaryText"] as? [String: Any])?["text"] as? String
                else { return nil }
                return UIPlace(main_text: mainText, secondary_text: secondaryText, placeID: placeId)
            }

            handler(places, nil)
        }
    }
    
    func get_info(place_id: String, handler: @escaping (PlaceResult?, Error?) -> Void) {
        let sessionToken = session?.uuidString ?? ""
        _get_request(
            baseurl: "https://places.googleapis.com/v1/places/\(place_id)",
            params: ["sessionToken": sessionToken],
            headers: [
                "X-Goog-Api-Key": GMAK,
                "X-Goog-FieldMask": "location,displayName"
            ]
        ) { [self] data, _, error in
            session = nil

            guard let d = data,
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let loc = json["location"] as? [String: Any],
                  let lat = loc["latitude"] as? Double,
                  let lng = loc["longitude"] as? Double,
                  let name = (json["displayName"] as? [String: Any])?["text"] as? String
            else { return handler(nil, error) }

            handler(PlaceResult(name: name, location: CLLocationCoordinate2D(latitude: lat, longitude: lng)), nil)
        }
    }
}
