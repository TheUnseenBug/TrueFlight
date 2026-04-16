//
//  TrueFlightWatchApp.swift
//  TrueFlight Watch App
//
//  Entry point for the Watch App. Uses ContentView from ContentView-TrueFlightWatchApp.swift.
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI

// Make sure ContentView-TrueFlightWatchApp.swift is included in this target.
@main
struct TrueFlight_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView() // From ContentView-TrueFlightWatchApp.swift
        }
    }
}
