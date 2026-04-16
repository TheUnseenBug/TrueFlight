//
//  ContentView.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI
import WatchConnectivity
import AVFoundation

// MARK: - Throw Model
struct Throw: Codable, Identifiable {
    let id = UUID()
    let userId: String
    let timestamp: TimeInterval
    let maxSpin: Double      // rad/s
    let maxAccel: Double    // Gs
    let throwType: String
    let speed: Double
    let hyzer: Double       // degrees
    let noseAngle: Double   // degrees
    
    var wobble: Double {
        abs(maxSpin - (maxAccel * 10)) // Estimate wobble from spin variance
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
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    @Published var throws: [Throw] = []
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
                    noseAngle: self.calculateNoseAngle(spin: maxSpin)
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
        try? audioSession.setCategory(.default, mode: .default, options: [.duckOthers])
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
        min(45, accel * 8) // Estimate based on acceleration
    }
    
    private func calculateNoseAngle(spin: Double) -> Double {
        max(-30, min(30, spin * 2)) // Estimate based on spin
    }
    
    private func saveThrowsToStorage() {
        if let encoded = try? JSONEncoder().encode(throws) {
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

// MARK: - Stat Card View
struct StatCard: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.title2)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    var latestThrow: Throw? {
        watchManager.throws.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Latest Throw
                    if let latest = latestThrow {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Latest Throw")
                                    .font(.headline)
                                Spacer()
                                Text(latest.throwType)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                            Text(latest.dateFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Stat Cards - Two Columns
                    if let latest = latestThrow {
                        VStack(spacing: 12) {
                            // Row 1
                            HStack(spacing: 12) {
                                StatCard(title: "Speed", value: latest.speed, unit: "rpm")
                                StatCard(title: "Spin", value: latest.maxSpin, unit: "rad/s")
                            }
                            
                            // Row 2
                            HStack(spacing: 12) {
                                StatCard(title: "Wobble", value: latest.wobble, unit: "")
                                StatCard(title: "Hyzer", value: latest.hyzer, unit: "°")
                            }
                            
                            // Row 3
                            HStack(spacing: 12) {
                                StatCard(title: "Nose Angle", value: latest.noseAngle, unit: "°")
                                Spacer()
                            }
                        }
                    }
                    
                    // Throws History
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Throw History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if watchManager.throws.isEmpty {
                            Text("No throws recorded yet")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            List(watchManager.throws) { throwRecord in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(throwRecord.throwType)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text(throwRecord.dateFormatted)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 16) {
                                        Label(String(format: "%.1f rpm", throwRecord.speed), systemImage: "bolt.fill")
                                            .font(.caption)
                                        Label(String(format: "%.1f rad/s", throwRecord.maxSpin), systemImage: "tornado")
                                            .font(.caption)
                                        Label(String(format: "%.1f°", throwRecord.hyzer), systemImage: "arrow.up.left")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("TrueFlight")
        }
    }
}

#Preview {
    ContentView()
}
