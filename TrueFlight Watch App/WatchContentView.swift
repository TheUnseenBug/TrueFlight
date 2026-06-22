import SwiftUI
import CoreMotion
import WatchConnectivity
import Combine

// MARK: - Throw Summary (Saved to DB)
struct ThrowSummary: Codable {
    let userId: String
    let timestamp: TimeInterval
    let maxSpin: Double      // rad/s
    let maxAccel: Double    // Gs
}

struct WatchContentView: View {

    // UI
    @State private var statusText = "Ready"
    @StateObject private var sessionManager = WatchSessionManager.shared

    // Motion
    private let motionManager = CMMotionManager()

    // Detection State
    @State private var releaseDetected = false
    @State private var maxSpin: Double = 0
    @State private var maxAccel: Double = 0
    @State private var gyroYAtRelease: Double = 0  // Track Y-axis rotation for spin direction
    @State private var accelZAtRelease: Double = 0  // Track Z-axis accel for launch angle
    @State private var accelVectorAtRelease: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @State private var gyroVectorAtRelease: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @State private var throwDuration: Double = 0.0
    @State private var releaseTime: TimeInterval = 0

    // Config
    private let sampleRate = 100.0
    private let accelThreshold = 2.5
    private let gyroThreshold = 8.0
    private let flightEndGyro = 1.0
    
    // Disc configuration - adjust to match your actual disc weight
    // Standard: 0.175 kg (175g), heavier drivers: 0.185-0.195 kg, lighter putters: 0.165 kg
    // The watch (~40g) will add to this, and proper mass compensation is applied server-side
    private let discMass = 0.185  // kg (adjust to your disc weight)

    // User (replace with auth later)
    private let userId = "user_123"

    var body: some View {
        VStack(spacing: 12) {
            Text(statusText)
                .font(.headline)
            
            Text(sessionManager.isArmedByPhone ? "Armed" : "Waiting for signal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            sessionManager.onArmCommand = { isArmed in
                if isArmed {
                    startMotion()
                } else {
                    stopMotion()
                }
            }
        }
    }

    // MARK: - Motion Handling
    func startMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            statusText = "Motion Unavailable"
            return
        }

        resetState()
        statusText = "Armed"

        motionManager.deviceMotionUpdateInterval = 1.0 / sampleRate

        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion = motion else { return }

            let accel = motion.userAcceleration
            let gyro = motion.rotationRate

            let accelMag = magnitude(accel.x, accel.y, accel.z)
            let gyroMag = magnitude(gyro.x, gyro.y, gyro.z)

            // Track peak values
            maxAccel = max(maxAccel, accelMag)
            maxSpin = max(maxSpin, gyroMag)

            // Release detection
            if !releaseDetected &&
                accelMag > accelThreshold &&
                gyroMag > gyroThreshold {

                releaseDetected = true
                releaseTime = motion.timestamp
                statusText = "Released 🚀"
                
                // Capture full acceleration and gyro vectors at release for physics calculations
                accelVectorAtRelease = (accel.x, accel.y, accel.z)
                gyroVectorAtRelease = (gyro.x, gyro.y, gyro.z)
                gyroYAtRelease = gyro.y  // Spin direction: positive Y = backhand
                accelZAtRelease = accel.z  // Vertical acceleration component
            }

            // End throw when spin drops below threshold (disc lands or stabilizes)
            if releaseDetected && gyroMag < flightEndGyro {
                throwDuration = motion.timestamp - releaseTime
                finalizeThrow(timestamp: motion.timestamp)
            }
        }
    }

    func stopMotion() {
        motionManager.stopDeviceMotionUpdates()
        statusText = "Idle"
        resetState()
    }

    // MARK: - Finalize & Send
    func finalizeThrow(timestamp: TimeInterval) {
        motionManager.stopDeviceMotionUpdates()

        let throwData = ThrowSummary(
            userId: userId,
            timestamp: timestamp,
            maxSpin: maxSpin,  // Send raw sensor values; server applies mass compensation
            maxAccel: maxAccel
        )

        // Determine spin direction: positive Y = backhand, negative Y = forehand
        let spinDirection = gyroYAtRelease > 0 ? "Backhand" : "Forehand"
        
        // Calculate launch angle from full acceleration vector using physics
        // Launch angle is the pitch angle of the throw
        // Derived from the angle of the acceleration vector from horizontal
        // let accelMagnitude = magnitude(accelVectorAtRelease.x, accelVectorAtRelease.y, accelVectorAtRelease.z)
        
        // Launch angle: angle between acceleration vector and horizontal plane
        // atan2(accelZ, sqrt(accelX^2 + accelY^2)) gives pitch angle
        let horizontalAccel = sqrt(accelVectorAtRelease.x * accelVectorAtRelease.x + 
                                   accelVectorAtRelease.y * accelVectorAtRelease.y)
        let launchAngleRad = atan2(accelZAtRelease, horizontalAccel)
        let launchAngle = max(0, min(45, launchAngleRad * 180.0 / .pi))

        // Convert from rad/s to RPM for downstream display
        let maxSpinRpm = (throwData.maxSpin * 60.0) / (2.0 * .pi)

        sendThrowToPhone(throwData, maxSpinRpm: maxSpinRpm, spinDirection: spinDirection, launchAngle: launchAngle)

        statusText = "Throw Saved ✅"
        resetState()
    }

    // MARK: - Networking
    func sendThrowToPhone(_ throwData: ThrowSummary, maxSpinRpm: Double, spinDirection: String, launchAngle: Double) {
        guard WCSession.isSupported() else {
            statusText = "Watch Connectivity Unavailable"
            return
        }

        // Units: maxSpin (rad/s), maxSpinRpm (rev/min), maxAccel (G), discMass (kg)
        let payload: [String: Any] = [
            "userId": throwData.userId,
            "timestamp": Date().timeIntervalSince1970,
            "maxSpin": throwData.maxSpin,
            "maxSpinRpm": maxSpinRpm,
            "maxAccel": throwData.maxAccel,
            "spinDirection": spinDirection,
            "launchAngle": launchAngle,
            "discMass": discMass  // Include disc mass for accurate server-side compensation
        ]

        WatchSessionManager.shared.send(message: payload)

        // Optional UI feedback based on reachability
        if WatchSessionManager.shared.isReachable {
            statusText = "Sent to phone"
        } else {
            statusText = "Queued for delivery"
        }
    }

    // MARK: - Helpers
    func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x*x + y*y + z*z)
    }

    func resetState() {
        releaseDetected = false
        maxSpin = 0
        maxAccel = 0
        gyroYAtRelease = 0
        accelZAtRelease = 0
        accelVectorAtRelease = (0, 0, 0)
        gyroVectorAtRelease = (0, 0, 0)
        throwDuration = 0.0
        releaseTime = 0
    }
}
