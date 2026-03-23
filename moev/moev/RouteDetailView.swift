//
//  RouteDetailView.swift
//  moev
//

import SwiftUI

struct RouteDetailView: View {
    let route: CombinedRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Leave at \(route.startTime.format("h:mm a"))")
                    .font(.headline)
                    .padding()

                ForEach(route.legs ?? []) { leg in
                    ForEach(leg.steps) { step in
                        stepRow(step)
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .background(UIColor.Theme.listBackgroundColor)
        .presentationDetents([.medium, .large])
    }

    func stepRow(_ step: CombinedStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            stepIcon(step)

            VStack(alignment: .leading, spacing: 3) {
                if let dept = step.departureTime {
                    Text(dept.format("h:mm a"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(stepLabel(step))
                    .font(.body)
                Text("\(Int(step.totalDuration / 60)) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(step.wait ? Color.gray.opacity(0.08) : Color.clear)
    }

    @ViewBuilder
    func stepIcon(_ step: CombinedStep) -> some View {
        if step.wait {
            Image(systemName: "clock")
                .frame(width: 40, height: 40)
                .background(Color(hex: "c4c4c4"))
                .cornerRadius(6)
        } else if let td = step.transitDetails, let line = td.transitLine {
            Text(line.nameShort ?? "")
                .foregroundColor(Color(hex: line.textColor ?? "000000"))
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Color(hex: line.color ?? "888888"))
                .cornerRadius(6)
        } else if let tm = step.travelMode {
            tm.to_swiftui_image()
                .frame(width: 40, height: 40)
                .background(Color(hex: "c4c4c4"))
                .cornerRadius(6)
        } else {
            Color(hex: "c4c4c4")
                .frame(width: 40, height: 40)
                .cornerRadius(6)
        }
    }

    func stepLabel(_ step: CombinedStep) -> String {
        if step.wait { return "Wait" }
        if let td = step.transitDetails, let line = td.transitLine {
            return line.name ?? line.nameShort ?? "Transit"
        }
        switch step.travelMode {
        case .WALK: return "Walk"
        case .DRIVE: return "Drive"
        case .BICYCLE: return "Bicycle"
        case .TWO_WHEELER: return "Scooter"
        default: return "Transit"
        }
    }
}
