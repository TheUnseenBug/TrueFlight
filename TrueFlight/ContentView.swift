//
//  ContentView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI
import WatchConnectivity
import AVFoundation
import Combine

// MARK: - Throw Model
struct Throw: Codable, Identifiable {
    var id = UUID()
    let userId: String
    let timestamp: TimeInterval
    let maxSpin: Double      // rad/s
    let maxAccel: Double    // Gs
    let throwType: String
    let speed: Double
    let hyzer: Double       // degrees
    let noseAngle: Double   // degrees
    
    var wobble: Double {
        // Wobble measures flight instability
        // High spin with low acceleration = unstable/wobbly flight
        // Low spin with high acceleration = stable flight
        // Formula: deviation from ideal stable ratio (spin:accel = 3.5:1)
        let stableRatio = maxAccel * 3.5
        return abs(maxSpin - stableRatio)
    }
    
    var dateFormatted: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    @Published var `throws`: [Throw] = []
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        loadThrowsFromStorage()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let userId = message["userId"] as? String,
               let timestamp = message["timestamp"] as? TimeInterval,
               let maxSpin = message["maxSpin"] as? Double,
               let maxAccel = message["maxAccel"] as? Double {
                
                let throwType = self.classifyThrow(spin: maxSpin, accel: maxAccel)
                let rpmSpeed = maxSpin * 9.5493 // Convert rad/s to rpm
                let newThrow = Throw(
                    userId: userId,
                    timestamp: timestamp,
                    maxSpin: maxSpin,
                    maxAccel: maxAccel,
                    throwType: throwType,
                    speed: rpmSpeed,
                    hyzer: self.calculateHyzer(accel: maxAccel),
                    noseAngle: self.calculateNoseAngle(spin: maxSpin, accel: maxAccel)
                )
                
                self.throws.insert(newThrow, at: 0)
                self.saveThrowsToStorage()
                self.speakThrowMetrics(newThrow)
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    
    private func speakThrowMetrics(_ throwRecord: Throw) {
        // Configure audio session for headphones
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? audioSession.setActive(true)
        
        // Format the metrics text
        let speedText = String(format: "%.0f", throwRecord.speed)
        let spinText = String(format: "%.1f", throwRecord.maxSpin)
        let noseText = String(format: "%.0f", throwRecord.noseAngle)
        
        let utterance = AVSpeechUtterance(string: "Speed \(speedText) rpm, Spin \(spinText) radians per second, Nose angle \(noseText) degrees")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        // Stop any previous speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    private func classifyThrow(spin: Double, accel: Double) -> String {
        if spin > 8 && accel > 3 { return "Power Throw" }
        if spin < 3 { return "Straight" }
        if accel > 2.5 { return "Forehand" }
        return "Backhand"
    }
    
    private func calculateHyzer(accel: Double) -> Double {
        // Hyzer angle (pitch): how nose-up the disc is at release
        // Higher acceleration = more force = higher hyzer angle
        // Formula: scales acceleration to realistic hyzer range (-30 to 45 degrees)
        // Base: 0° at 1.5 Gs, increases 12° per additional G
        let baseAngle = (accel - 1.5) * 12.0
        return max(-30, min(45, baseAngle))
    }
    
    private func calculateNoseAngle(spin: Double, accel: Double) -> Double {
        // Nose angle (forward/backward tilt): affects distance and drop rate
        // High spin with moderate accel = nose up (stable, far flight)
        // Low spin or high accel = nose down (less distance, faster drop)
        // Formula: spin-to-accel ratio determines nose angle
        // Ideal ratio ~2.5:1, deviation scales angle
        if accel > 0 {
            let ratio = spin / (accel + 0.5)
            let noseAngle = (ratio - 2.5) * 8.0  // Scale deviation to degrees
            return max(-30, min(30, noseAngle))
        }
        return 0
    }
    
    private func saveThrowsToStorage() {
        if let encoded = try? JSONEncoder().encode(self.throws) {
            UserDefaults.standard.set(encoded, forKey: "storedThrows")
        }
    }
    
    private func loadThrowsFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "storedThrows"),
           let decoded = try? JSONDecoder().decode([Throw].self, from: data) {
            self.throws = decoded
        }
    }
}

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

// MARK: - Dashboard View
struct DashboardView: View {
    let latestThrow: Throw?
    let throwsList: [Throw]
    
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
                                    Text("Just now")
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
                                            Text("rpm")
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
                                            Text(String(format: "%.1f", latest.maxSpin))
                                                .font(.system(size: 32, weight: .bold))
                                            Text("rad/s")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Metrics Grid
                    if let latest = latestThrow {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                MetricCard(
                                    title: "Wobble",
                                    value: latest.wobble,
                                    unit: "",
                                    icon: "waveform.circle"
                                )
                                MetricCard(
                                    title: "Hyzer",
                                    value: latest.hyzer,
                                    unit: "°",
                                    icon: "arrow.up.right"
                                )
                                MetricCard(
                                    title: "Nose",
                                    value: latest.noseAngle,
                                    unit: "°",
                                    icon: "arrow.forward"
                                )
                            }
                        }
                        .padding(.horizontal)
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
                                    value: String(format: "%.0f rpm", throwsList.prefix(10).map { $0.speed }.reduce(0, +) / Double(throwsList.prefix(10).count))
                                )
                                QuickStatBox(
                                    label: "Max Spin",
                                    value: String(format: "%.1f rad/s", throwsList.max(by: { $0.maxSpin < $1.maxSpin })?.maxSpin ?? 0)
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
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - History View
struct HistoryView: View {
    let throwsList: [Throw]
    
    var body: some View {
        NavigationStack {
            VStack {
                if throwsList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Throws Yet")
                            .font(.headline)
                        Text("Start recording throws from your watch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List(throwsList) { throwRecord in
                        HistoryRow(throwRecord: throwRecord)
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Stats View
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
                                unit: "rpm"
                            )
                            StatBoxLarge(
                                title: "Average Spin",
                                value: String(format: "%.1f", avgSpin),
                                unit: "rad/s"
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

// MARK: - Helper Components
struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .center, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 24, weight: .bold))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickStatBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatBoxLarge: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(.system(size: 48, weight: .bold))
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct HistoryRow: View {
    let throwRecord: Throw
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(throwRecord.throwType)
                        .fontWeight(.semibold)
                    Text(throwRecord.dateFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 16) {
                Label(String(format: "%.0f rpm", throwRecord.speed), systemImage: "bolt.fill")
                    .font(.caption)
                Label(String(format: "%.1f rad/s", throwRecord.maxSpin), systemImage: "tornado")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

