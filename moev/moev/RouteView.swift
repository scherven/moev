//
//  RouteView.swift
//  moev
//
//  Created by Simon Chervenak on 12/7/23.
//

import Foundation
import SwiftUI

struct RouteView: View {
    @State public var route: CombinedRoute
    var onSelect: (CombinedRoute) -> Void = { _ in }

    var body: some View {
        VStack {
            ForEach(route.legs ?? []) { leg in
                stepsList(leg.steps)
            }
            Text("Leave at \(route.startTime.format("hh:mm"))")
        }
        .onTapGesture {
            onSelect(route)
        }
    }
    
    func stepsList(_ steps: [CombinedStep]) -> some View {
        return ZStack {
            dots()
                .position(x: 0, y: 10)
            ForEach(steps) { step in
                stepsView(step)
                    .position(x: CGFloat(xposition(for: step)), y: 10)
            }
        }
        .frame(width: CGFloat(xposition(for: route.maxDuration)))
    }
    
    func stepsView(_ step: CombinedStep) -> some View {
        return VStack {
            if step.wait {
                Image(systemName: "clock")
                    .frame(width: CGFloat(width(for: step)), height: 40)
                    .background(Color(hex: "c4c4c4"))
            } else if let td = step.transitDetails {
                VStack {
                    Text(td.transitLine!.nameShort ?? "")
                        .foregroundColor(Color(hex: td.transitLine!.textColor!)) // Set text color using hex value
                        .lineLimit(1)
                        .font(.system(size: 24))
                }
                .frame(width: CGFloat(width(for: step)), height: 40)
                .background(Color(hex: td.transitLine!.color!)) // Set background color using hex value
            }
            else if let tm = step.travelMode {
                tm.to_swiftui_image()
                    .frame(width: CGFloat(width(for: step)), height: 40)
                    .background(Color(hex: "c4c4c4"))
            }
        }
    }
    
    func dots() -> some View {
        return HStack(spacing: 10) {
            ForEach(1...(Int(xposition(for: route.durationFromNow) / 100) + 2), id:\.self) { i in
                Circle()
                    .frame(width: 3, height: 3)
                    .foregroundColor(Color.blue) // You can change the color as desired

            }
        }
    }
}
