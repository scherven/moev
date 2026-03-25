//
//  MultiRouteView.swift
//  moev
//

import SwiftUI

/// Renders all legs of a multi-stop journey as one continuous horizontal
/// timeline.  Steps are positioned by their absolute departure time
/// (same coordinate system as RouteView), so A→B and B→C segments land
/// naturally next to each other.  A dwell block is drawn between
/// segments wherever dwellMinutes is set.
struct MultiRouteView: View {
    let multiRoute: MultiLegRoute
    let onSelect: () -> Void

    private var totalDuration: Double {
        multiRoute.segments.map { $0.maxDuration }.max() ?? 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            dotsView()
                .position(x: 0, y: 10)

            ForEach(Array(multiRoute.segments.enumerated()), id: \.offset) { idx, route in
                // All steps from this segment
                ForEach(route.legs ?? []) { leg in
                    ForEach(leg.steps) { step in
                        stepView(step)
                            .position(x: CGFloat(xposition(for: step)), y: 10)
                    }
                }

                // Dwell block after this segment (not after the last one)
                if idx < multiRoute.segments.count - 1,
                   idx < multiRoute.dwellMinutes.count,
                   let dwell = multiRoute.dwellMinutes[idx],
                   let lastStep = route.legs?.last?.steps.last,
                   let arrival = lastStep.departureTime?.addingTimeInterval(lastStep.totalDuration) {
                    let dwellStep = CombinedStep(duration: Double(dwell * 60), departureTime: arrival)
                    dwellView(step: dwellStep, minutes: dwell)
                        .position(x: CGFloat(xposition(for: dwellStep)), y: 10)
                }
            }

            // "Leave at" label below the bar
            if let first = multiRoute.segments.first {
                Text("Leave at \(first.startTime.format("h:mm a"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .position(x: 50, y: 38)
            }
        }
        .frame(width: CGFloat(xposition(for: totalDuration)), height: 60)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
    }

    // MARK: - Step rendering (mirrors RouteView.stepsView)

    @ViewBuilder
    func stepView(_ step: CombinedStep) -> some View {
        if step.wait {
            Image(systemName: "clock")
                .frame(width: CGFloat(width(for: step)), height: 40)
                .background(Color(hex: "c4c4c4"))
                .cornerRadius(4)
        } else if let td = step.transitDetails, let line = td.transitLine {
            Text(line.nameShort ?? "")
                .foregroundColor(Color(hex: line.textColor ?? "000000"))
                .lineLimit(1)
                .font(.system(size: 24))
                .frame(width: CGFloat(width(for: step)), height: 40)
                .background(Color(hex: line.color ?? "888888"))
                .cornerRadius(4)
        } else if let tm = step.travelMode {
            tm.to_swiftui_image()
                .frame(width: CGFloat(width(for: step)), height: 40)
                .background(Color(hex: "c4c4c4"))
                .cornerRadius(4)
        }
    }

    /// Orange-tinted block shown between segments to represent dwell time.
    func dwellView(step: CombinedStep, minutes: Int) -> some View {
        VStack(spacing: 1) {
            Text("⏱")
                .font(.system(size: 14))
            Text(minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h\(minutes % 60 == 0 ? "" : "\(minutes % 60)m")")
                .font(.system(size: 9, weight: .medium))
        }
        .frame(width: max(CGFloat(width(for: step)), 28), height: 40)
        .background(Color.orange.opacity(0.4))
        .cornerRadius(4)
    }

    func dotsView() -> some View {
        let count = max(Int(xposition(for: totalDuration) / 100) + 2, 1)
        return HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .frame(width: 3, height: 3)
                    .foregroundColor(.blue)
            }
        }
    }
}
