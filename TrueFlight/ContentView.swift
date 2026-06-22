//
//  ContentView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    @State private var selectedTab = 0
    
    var latestThrow: Throw? {
        watchManager.throws.first
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Dashboard Tab
            DashboardView(latestThrow: latestThrow, throwsList: watchManager.throws)
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            
            // MARK: - History Tab
            HistoryView(throwsList: watchManager.throws)
                .tag(1)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
            
            // MARK: - Stats Tab
            StatsView(throwsList: watchManager.throws)
                .tag(2)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
    }
}

#Preview {
    ContentView()
}
