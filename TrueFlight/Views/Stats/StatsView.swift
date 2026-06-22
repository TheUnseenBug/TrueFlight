//
//  StatsView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct StatsView: View {
    let throwsList: [Throw]
    
    var avgSpeed: Double {
        throwsList.isEmpty ? 0 : throwsList.map { $0.speed }.reduce(0, +) / Double(throwsList.count)
    }
    
    var avgSpin: Double {
        throwsList.isEmpty ? 0 : throwsList.map { $0.maxSpin }.reduce(0, +) / Double(throwsList.count)
    }
    
    var avgWobble: Double {
        throwsList.isEmpty ? 0 : throwsList.map { $0.wobble }.reduce(0, +) / Double(throwsList.count)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Statistics")
                        .font(.system(size: 32, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    if throwsList.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Data Yet")
                                .font(.headline)
                            Text("Record throws to see statistics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 12) {
                            StatBoxLarge(
                                title: "Average Speed",
                                value: String(format: "%.0f", avgSpeed),
                                unit: "km/h"
                            )
                            StatBoxLarge(
                                title: "Average Spin",
                                value: String(format: "%.0f", avgSpin * 9.5493),
                                unit: "rpm"
                            )
                            StatBoxLarge(
                                title: "Average Wobble",
                                value: String(format: "%.1f", avgWobble),
                                unit: ""
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Stats")
        }
    }
}
