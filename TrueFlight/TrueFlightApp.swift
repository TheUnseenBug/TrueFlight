//
//  TrueFlightApp.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI
import WatchConnectivity

@main
struct TrueFlightApp: App {
    init() {
        // Ensure WCSession delegate is set and session is activated at launch
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

