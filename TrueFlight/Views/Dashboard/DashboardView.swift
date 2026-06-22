//
//  DashboardView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

struct DashboardView: View {
    let latestThrow: Throw?
    let throwsList: [Throw]
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TrueFlight")
                            .font(.system(size: 32, weight: .bold))
                        Text(throwsList.isEmpty ? "No throws yet" : "\(throwsList.count) throws recorded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Arm/Disarm Toggle Control
                    Button(action: {
                        if watchManager.isArmed {
                            watchManager.disarmWatch()
                        } else {
                            watchManager.armWatch()
                        }
                        watchManager.isArmed.toggle()
                    }) {
                        HStack {
                            Image(systemName: watchManager.isArmed ? "circle.fill" : "circle")
                                .foregroundStyle(watchManager.isArmed ? .red : .green)
                            Text(watchManager.isArmed ? "Disarm" : "Arm")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundStyle(.white)
                        .background(watchManager.isArmed ? Color(.systemRed) : Color(.systemGreen))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // Latest Throw Card (Large)
                    if let latest = latestThrow {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Latest Throw")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(latest.throwType)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Time")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(latest.dateFormatted)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            Divider()
                            
                            // Large Speed Display
                            VStack(spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Speed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        HStack(alignment: .center, spacing: 4) {
                                            Text(String(format: "%.0f", latest.speed))
                                                .font(.system(size: 44, weight: .bold))
                                            Text("km/h")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Spin")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        HStack(alignment: .center, spacing: 4) {
                                            Text(String(format: "%.1f", latest.maxSpin * 9.5493))
                                                .font(.system(size: 32, weight: .bold))
                                            Text("rpm")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Launch Angle Display
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Launch Angle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.0f", latest.launchAngle))
                                            .font(.system(size: 28, weight: .bold))
                                        Text("°")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Nose Angle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.0f", latest.noseAngle))
                                            .font(.system(size: 28, weight: .bold))
                                        Text("°")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hyzer")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.0f", latest.hyzer))
                                            .font(.system(size: 28, weight: .bold))
                                        Text("°")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    
                                }
                                
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                        
                        // Quick Stats
                        if !throwsList.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Stats")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 12) {
                                    QuickStatBox(
                                        label: "Avg Speed",
                                        value: String(format: "%.0f km/h", throwsList.prefix(10).map { $0.speed }.reduce(0, +) / Double(throwsList.prefix(10).count))
                                    )
                                    QuickStatBox(
                                        label: "Max Spin",
                                        value: String(format: "%.0f rpm", (throwsList.max(by: { $0.maxSpin < $1.maxSpin })?.maxSpin ?? 0) * 9.5493)
                                    )
                                    QuickStatBox(
                                        label: "Total",
                                        value: "\(throwsList.count) throws"
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    
                }
                .navigationTitle("Dashboard")
            }
        }
    }
}
