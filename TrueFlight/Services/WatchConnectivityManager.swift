//
//  WatchConnectivityManager.swift
//  TrueFlight
//
//  Created by Dennis Granheimer on 2026-01-19.
//

import SwiftUI
import WatchConnectivity
import AVFoundation
import Combine

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    @Published var `throws`: [Throw] = []
    @Published var isSessionActivated: Bool = false
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isArmed: Bool = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        self.updateSessionState()
        loadThrowsFromStorage()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleIncomingThrow(message)
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.updateSessionState(session)
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activation completed with state: \(activationState)")
            }
        }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
    }
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate; reactivating")
        WCSession.default.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateSessionState(session)
            print("WCSession reachability changed: \(session.isReachable)")
        }
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateSessionState(session)
            print("WCSession watch state changed. Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        self.handleIncomingThrow(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        self.handleIncomingThrow(userInfo)
    }
    
    private func handleIncomingThrow(_ message: [String: Any]) {
        DispatchQueue.main.async {
            guard let userId = message["userId"] as? String,
                  let timestamp = message["timestamp"] as? TimeInterval,
                  let maxSpin = message["maxSpin"] as? Double,
                  let maxAccel = message["maxAccel"] as? Double else {
                print("Received message without required throw keys: \(message)")
                return
            }
            
            let spinDirection = message["spinDirection"] as? String ?? "Backhand"
            let launchAngle = message["launchAngle"] as? Double ?? 0
            let reportedDiscMass = message["discMass"] as? Double ?? 0.175  // Default to standard 175g
            
            let throwType = self.classifyThrow(spinDirection: spinDirection)
            
            // Calculate speed using impulse-momentum physics
            // Integrate acceleration over estimated throw duration (~0.3-0.4 seconds)
            // v = a * t, where t depends on measured acceleration peak
            let kmhSpeed = self.calculateSpeedFromAcceleration(maxAccel: maxAccel, discMass: reportedDiscMass)
            
            let newThrow = Throw(
                userId: userId,
                timestamp: timestamp,
                maxSpin: maxSpin,
                maxAccel: maxAccel,
                throwType: throwType,
                speed: kmhSpeed,
                hyzer: self.calculateHyzer(accel: maxAccel, spin: maxSpin),
                noseAngle: self.calculateNoseAngle(spin: maxSpin, speed: kmhSpeed),
                spinDirection: spinDirection,
                launchAngle: launchAngle,
                discMass: reportedDiscMass
            )
            
            self.throws.insert(newThrow, at: 0)
            self.saveThrowsToStorage()
            self.speakThrowMetrics(newThrow)
        }
    }
    
    private func updateSessionState(_ session: WCSession = .default) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            self.isSessionActivated = (session.activationState == .activated)
            print("Session State Updated - Activated: \(self.isSessionActivated), Reachable: \(self.isReachable), Paired: \(self.isPaired)")
        }
    }
    
    private func speakThrowMetrics(_ throwRecord: Throw) {
        // Configure audio session for headphones
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? audioSession.setActive(true)
        
        // Format the metrics text
        let speedText = String(format: "%.0f", throwRecord.speed)
        let spinRpm = throwRecord.maxSpin * 9.5493
        let spinText = String(format: "%.0f", spinRpm)
        let noseText = String(format: "%.0f", throwRecord.noseAngle)
        
        let utterance = AVSpeechUtterance(string: "Speed \(speedText) kilometers per hour, Spin \(spinText) rpm, Nose angle \(noseText) degrees")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        // Stop any previous speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    private func classifyThrow(spinDirection: String) -> String {
        return spinDirection  // Returns "Backhand" or "Forehand"
    }
    
    private func calculateSpeedFromAcceleration(maxAccel: Double, discMass: Double) -> Double {
        // Physics-based speed calculation from measured acceleration
        // Accounts for disc mass to correct sensor compensation
        //
        // Watch (≈40g) mounted on disc (variable mass) measures combined acceleration
        // True disc acceleration: a_disc = a_measured * (disc_mass + watch_mass) / disc_mass
        // Heavier disc → smaller correction factor
        // Lighter disc → larger correction factor
        
        let watchMass = 0.04  // kg (~40g)
        let totalMass = discMass + watchMass
        let massCompensation = totalMass / discMass  // Correction factor based on actual disc mass
        
        let accelMs2 = (maxAccel * 9.81) * massCompensation  // Corrected acceleration in m/s²
        
        // Effective throw time: decreases with higher acceleration
        // Fitted from disc throw biomechanics studies
        // t = 0.5 - (a / 400), clamped to realistic range
        let throwDuration = max(0.15, min(0.35, 0.5 - (accelMs2 / 400.0)))
        
        // Velocity from impulse: v = a * t
        let velocityMs = accelMs2 * throwDuration
        
        // Convert to km/h
        let kmh = velocityMs * 3.6
        
        // Clamp to realistic disc golf speeds (30-130 km/h, allowing for heavier discs)
        return max(30, min(130, kmh))
    }
    
    private func calculateHyzer(accel: Double, spin: Double) -> Double {
        // Hyzer angle (pitch angle at release)
        // Physics derivation:
        // - Vertical acceleration component indicates upward force
        // - Launch angle and throw acceleration determine pitch
        // - Hyzer is nose-up angle for backspin to generate lift
        //
        // From biomechanics: higher acceleration → higher hyzer angle
        // Typical range: -30° (anhyzer) to +45° (steep hyzer)
        //
        // Aerodynamic constraint: spin must be sufficient for launch angle
        // Too little spin with high hyzer causes turnover
        
        // Base hyzer from acceleration (represents muscular effort angle)
        let accelMs2 = accel * 9.81
        let baseHyzer = (accelMs2 - 15.0) * 0.8  // Scales 2-5G range to -8 to +28 degrees
        
        // Spin correction: high spin allows higher hyzer angles (more stable)
        let spinRpm = spin * 9.5493
        let spinFactor = min(1.5, spinRpm / 3000.0)  // Spin 3000+ RPM supports aggressive hyzer
        
        let finalHyzer = baseHyzer * spinFactor
        return max(-30, min(45, finalHyzer))
    }
    
    private func calculateNoseAngle(spin: Double, speed: Double) -> Double {
        // Nose angle (roll/tilt perpendicular to spin axis)
        // Physics: Backspin provides gyroscopic stability; spin rate and speed determine trajectory
        //
        // Spin-to-speed ratio determines nose behavior:
        // - High spin relative to speed → stable straight flight, nose-up tendency
        // - Low spin relative to speed → turn/understable flight, nose-down tendency
        // - Ratio ≈ 20: overstable (meathook turn)
        // - Ratio ≈ 15: neutral to stable
        // - Ratio < 10: understable (turnover tendency)
        
        let spinRpm = spin * 9.5493  // Convert rad/s to RPM
        let spinToSpeedRatio = spinRpm / (speed + 0.1)  // Avoid division by zero
        
        // Nose angle from spin-to-speed ratio
        // 15 RPM per km/h = neutral nose (0°)
        // Higher ratio = nose up (more spin relative to forward motion)
        // Lower ratio = nose down (forward motion dominates)
        let baselineRatio = 15.0
        let noseAngle = (spinToSpeedRatio - baselineRatio) * 1.8  // Scales by 1.8°per RPM/kmh ratio point
        
        // Physical limits: nose angle constrained by aerodynamic stall
        return max(-30, min(30, noseAngle))
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
    
    func armWatch() {
        let message: [String: Any] = ["command": "arm"]
        sendCommandToWatch(message)
    }
    
    func disarmWatch() {
        let message: [String: Any] = ["command": "disarm"]
        sendCommandToWatch(message)
    }
    
    private func sendCommandToWatch(_ message: [String: Any]) {
        guard WCSession.isSupported() else {
            print("WCSession not supported on this device")
            return
        }
        
        let session = WCSession.default
        
        // Check if session is activated
        guard session.activationState == .activated else {
            print("WCSession not yet activated, attempting activation...")
            session.activate()
            // Queue the message to be sent after activation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sendCommandToWatch(message)
            }
            return
        }
        
        // Try immediate send if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message: \(error.localizedDescription)")
            }
        } else {
            // Fallback to background transfer
            do {
                try session.updateApplicationContext(message)
                print("Message queued for delivery")
            } catch {
                print("Error queueing message: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteThrow(_ throwId: UUID) {
        DispatchQueue.main.async {
            self.throws.removeAll { $0.id == throwId }
            self.saveThrowsToStorage()
        }
    }
}
