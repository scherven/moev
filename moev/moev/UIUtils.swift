//
//  UIUtils.swift
//  moev
//
//  Created by Simon Chervenak on 12/7/23.
//

import Foundation
import SwiftUI
import MapKit

// https://stackoverflow.com/questions/56874133/use-hex-color-in-swiftui
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


extension UIColor {
  struct Theme {
    static var listBackgroundColor = Color(hex: "ebf3fc")
    static var searchColor = Color(hex: "31f57f")
  }
}

func _hm(date: Date, clamp: Bool) -> (Double, Double) {
    let cal = Calendar.current
    var hour = cal.component(.hour, from: date)
    var minutes = cal.component(.minute, from: date)
    if clamp {
        if minutes > 30 {
//            hour += 1
            minutes = 30
        } else {
            minutes = 0
        }
    }
    return (Double(hour), Double(minutes))
}

func _hm(plus: Int, clamp: Bool) -> (Double, Double) {
    let date = Date(timeIntervalSinceNow: TimeInterval(plus * 30 * 60))
    return _hm(date: date, clamp: clamp)
}

func time(plus: Int) -> String {
    let (hour, minutes) = _hm(plus: plus, clamp: true)
    let padh = String(repeating: "0", count: hour < 10 ? 1 : 0)
    let padm = String(repeating: "0", count: minutes < 10 ? 1 : 0)
    return "\(padh)\(hour):\(padm)\(minutes)"
}

func time(plus: Int) -> Double {
    let (h1, m1) = _hm(date: Date(), clamp: false)
    let (h2, m2) = _hm(plus: plus, clamp: true)
//    print(h1, m1, h2, m2, xposition(for: ((h2 - h1) * 3600 + (m2 - m1) * 60) + (h2 < h1 ? 86400 : 0)))
    return ((h2 - h1) * 3600 + (m2 - m1) * 60) + (h2 < h1 ? 86400 : 0)
}

func time(date: Date) -> Double {
    let (h1, m1) = _hm(date: Date.now, clamp: false)
    let (h2, m2) = _hm(date: date, clamp: false)
//    print(h1, m1, h2, m2, xposition(for: ((h2 - h1) * 3600 + (m2 - m1) * 60) + (h2 < h1 ? 86400 : 0)))
    return ((h2 - h1) * 3600 + (m2 - m1) * 60) + (h2 < h1 ? 86400 : 0)
}

func time(timestamp: String?) -> Double? {
    if timestamp == nil {
        return nil
    }
    return time(date: date(from: timestamp!)!)
}

func xposition(for time: Double) -> Double {
    // time in seconds from now
    return time / 60 * 4  // 4 pixels per minute
}

func xposition(for step: CombinedStep) -> Double {
    return xposition(for: time(date: step.departureTime ?? Date.now)) + width(for: step) / 2
}

func width(for step: CombinedStep) -> Double {
    return xposition(for: step.totalDuration)
}

func date(from timestamp: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter.date(from: timestamp)
}

struct Annotation: Identifiable {
    var id: Int

    var location: CLLocationCoordinate2D?
    var name: String
    var placeID: String = ""
    var placeHolder: String = "Next location..."
    var justChanged: Bool = false
    var departureTime: Date? = nil
    var dwellMinutes: Int? = nil
}

struct UIPolyline: Identifiable {
    var id: Int
    
    var polyline: MKPolyline
}

struct UIPlace: Identifiable, Codable {
    var id = UUID()

    var main_text: String
    var secondary_text: String
    var placeID: String
}

struct UIRoutes: Identifiable {
    var id: Int
    var routes: [CombinedRoute]
}

// One complete journey: ordered segments (A→B, B→C …) plus optional
// dwell time between each pair.  dwellMinutes[i] is the time spent at
// the stop between segments[i] and segments[i+1].
/// Carries the annotation index into a .sheet(item:) closure so SwiftUI
/// always passes the current value rather than a stale capture.
struct TimePickerItem: Identifiable {
    let id: Int  // annotation index
}

struct MultiLegRoute: Identifiable {
    var id = UUID()
    var segments: [CombinedRoute]
    var dwellMinutes: [Int?]
}

extension Date {
    func format(_ format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
