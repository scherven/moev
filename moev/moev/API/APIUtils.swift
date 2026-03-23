//
//  Utils.swift
//  moev
//
//  Created by Simon Chervenak on 12/6/23.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

extension KeyedDecodingContainer {
    public func decodeIfPresent(_ type: [String: Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [String: Any]? {
        guard let data = try? self.decode(Data.self, forKey: key) else {
            return nil
        }

        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    public func decodeIfPresent(_ type: [[String: Any]].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [[String: Any]]? {
        guard let data = try? self.decode(Data.self, forKey: key) else {
            return nil
        }

        return try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
    }
}

extension KeyedEncodingContainer {
    public mutating func encodeIfPresent(_ value: [String: Any]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard let value = value else {
            return
        }

        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        try self.encode(data, forKey: key)
    }
    
    public mutating func encodeIfPresent(_ value: [[String: Any]]?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard let value = value else {
            return
        }

        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        try self.encode(data, forKey: key)
    }
}

extension Polyline {
    func decode() -> MKPolyline {
        // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
        var points: [CLLocationCoordinate2D] = []
        
        var point = ""
        var data: [Double] = []
        var last: [Double] = [0, 0]
                        
        for (i, char) in (encodedPolyline ?? "").enumerated() {
            point.append(char)
            if char.asciiValue! >= 95 && i != encodedPolyline!.count - 1 {
                continue
            }
            
            let val = point.map { c in
                var v = c.asciiValue! - 63 // remove ASCII-fication
                if v >= 32 { // remove continuation bit
                    v -= 32
                }
                
                var s = String(v, radix: 2)
                s = String(repeating: "0", count: 5 - s.count) + s // pad to chunks of 5
                return s
            }.reversed().joined() // reverse chunk order
            
            var i = Int("0" + val.dropLast(), radix: 2)! // right shift
            if val.last! == "1" { // 2s complement
                i = -i - 1
            }
            
            data.append(Double(i) / 100000.0) // convert back to coordinate range
            
            if data.count == 2 {
                last = [last[0] + data[0], last[1] + data[1]]
                
                let coord = CLLocationCoordinate2D(latitude: last[0], longitude: last[1])
                points.append(coord)
                data = []
            }
            
            point = ""
        }
        
        return MKPolyline(coordinates: points, count: points.count)
    }
}

extension CLLocationCoordinate2D {
    func toWaypoint() -> Waypoint {
        return Waypoint(
            location: Location(
                latLng: LatLng(
                    latitude: latitude,
                    longitude: longitude
                )
            )
        )
    }
}

// https://developers.google.com/maps/documentation/places/web-service/autocomplete#PlaceAutocompletePrediction
enum PlacesAutocompleteStatus: String, Codable {
    case OK
    case ZERO_RESULTS
    case INVALID_REQUEST
    case OVER_QUERY_LIMIT
    case REQUEST_DENIED
    case UNKNOWN_ERROR
}

enum PlacesDetailsStatus: String, Codable {
    case OK
    case ZERO_RESULTS
    case INVALID_REQUEST
    case OVER_QUERY_LIMIT
    case REQUEST_DENIED
    case UNKNOWN_ERROR
}

extension RouteTravelMode {
    func to_swiftui_image() -> some View {
        let img = switch self {
            case .BICYCLE: "bicycle"
            case .WALK: "figure.walk"
            case .TRAVEL_MODE_UNSPECIFIED: "questionmark.circle"
            case .DRIVE: "car"
            case .TWO_WHEELER: "number" // todo
            case .TRANSIT: "bus" //todo
        }
        
        return Image(systemName: img)
    }
}

func convert_duration(_ duration: String?) -> Double {
    guard let d = duration else {
        return 0
    }
    return Double(String(d.dropLast()))!
}

//https://stackoverflow.com/questions/32606989/converting-an-unsafepointer-with-length-to-a-swift-array-type
func convert<T>(count: Int, data: UnsafeMutablePointer<T>) -> [T] {
    let buffer = UnsafeBufferPointer(start: data, count: count);
    return Array(buffer)
}

struct CombinedStep: Identifiable {
    var id = UUID()
    var totalDuration: Double
    var startLocation: Location?
    var endLocation: Location?
    var polyline: MKMultiPolyline?
    var transitDetails: RouteLegStepTransitDetails?
    var travelMode: RouteTravelMode?
    var departureTime: Date?
    var wait: Bool = false
    
    init(from steps: [RouteLegStep]) {
        totalDuration = 0
        var points: [MKPolyline] = []
        
        for step in steps {
            totalDuration += convert_duration(step.staticDuration)
            if step.travelMode != .WALK {
                startLocation = step.startLocation
                endLocation = step.endLocation
                transitDetails = step.transitDetails
                travelMode = step.travelMode
                if let p = step.polyline {
                    points.append(p.decode())
                }
                if let t = step.transitDetails?.stopDetails?.departureTime {
                    departureTime = date(from: t)
                }
            } else {
                if startLocation == nil {
                    startLocation = step.startLocation
                }
                endLocation = step.endLocation
                transitDetails = step.transitDetails
                travelMode = .WALK
                if let p = step.polyline {
                    points.append(p.decode())
                }
            }
        }
        
        polyline = MKMultiPolyline(points)
    }
    
    init(duration: Double, departureTime: Date) {
        totalDuration = duration
        self.departureTime = departureTime
        wait = true
    }
    
    func toString() -> String {
        return "\(totalDuration) \(travelMode) \(departureTime)"
    }
}

struct CombinedLeg: Identifiable {
    var id = UUID()
    var steps: [CombinedStep]
}

struct CombinedRoute: Identifiable {
    var id = UUID()
    
    var legs: [CombinedLeg]?
    var durationFromNow: Double
    var startTime: Date
    var maxDuration: Double
}

extension Route {
    func combine() -> CombinedRoute {
        let legs = legs?.map { i in CombinedLeg(steps: combineWalks(steps: i.steps!)) }
        var d = convert_duration(duration)
        var startTime = Date.now
        if legs?.count ?? 0 > 0 && legs![0].steps[0].departureTime != nil {
            startTime = legs![0].steps[0].departureTime!
            d += legs![0].steps[0].departureTime!.timeIntervalSinceNow
        }
        return CombinedRoute(legs: legs, durationFromNow: d, startTime: startTime, maxDuration: 0)
    }
}

func combineRoutes(routes: [Route]) -> [CombinedRoute] {
    var maxDuration: Double = 0
    var cRoutes = routes.map { route in
        let c = route.combine()
        if c.durationFromNow > maxDuration {
            maxDuration = c.durationFromNow
        }
        return c
    }
    
    for i in 0..<cRoutes.count {
        cRoutes[i].maxDuration = maxDuration
    }
    
    return cRoutes
}

func combineWalks(steps: [RouteLegStep]) -> [CombinedStep] {
    var newSteps: [CombinedStep] = []
    
    var currentStep: [RouteLegStep] = []
    var lastArrival: Date? = nil
    for step in steps {
        if step.travelMode != .WALK {
            var prevStep: CombinedStep?
            if currentStep.count > 0 {
                prevStep = CombinedStep(from: currentStep)
                currentStep = []
            }
            let transitStep = CombinedStep(from: [step])
            let d = transitStep.departureTime!
            if var p = prevStep {
                if let la = lastArrival {
                    p.departureTime = la
                } else {
                    p.departureTime = d.addingTimeInterval(-p.totalDuration)
                }
                lastArrival = d.addingTimeInterval(transitStep.totalDuration)
                newSteps.append(p)
                let end = p.departureTime!.addingTimeInterval(p.totalDuration)
                let diff = d.timeIntervalSince(end)
                print("diff", diff)
                if diff > 0 {
                    newSteps.append(CombinedStep(duration: diff, departureTime: end))
                }
            }
            newSteps.append(transitStep)
        } else {
            currentStep.append(step)
        }
    }
    
    if currentStep.count > 0 {
        var walkStep = CombinedStep(from: currentStep)
        if newSteps.count > 0 {
            let lastStep = newSteps[newSteps.count - 1]
            if let d = lastStep.departureTime {
                walkStep.departureTime = d.addingTimeInterval(Double(lastStep.totalDuration))
            }
        }
        newSteps.append(walkStep)
    }
    
    print("combined walks!")
    print(newSteps.map { i in i.toString() })
    
    return newSteps
}
