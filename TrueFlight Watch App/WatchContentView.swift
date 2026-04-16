import SwiftUI
import CoreMotion
import WatchConnectivity

// MARK: - Throw Summary (Saved to DB)
struct ThrowSummary: Codable {
    let userId: String
    let timestamp: TimeInterval
    let maxSpin: Double      // rad/s
    let maxAccel: Double    // Gs
}

struct WatchContentView: View {

    // UI
    @State private var statusText = "Idle"
    @State private var isArmed = false

    // Motion
    private let motionManager = CMMotionManager()

    // Detection State
    @State private var releaseDetected = false
    @State private var maxSpin: Double = 0
    @State private var maxAccel: Double = 0

    // Config
    private let sampleRate = 100.0
    private let accelThreshold = 2.5
    private let gyroThreshold = 8.0
    private let flightEndGyro = 1.0

    // User (replace with auth later)
    private let userId = "user_123"

    var body: some View {
        VStack(spacing: 12) {
            Text(statusText)
                .font(.headline)

            Button(isArmed ? "Disarm" : "Arm Throw") {
                isArmed ? stopMotion() : startMotion()
                isArmed.toggle()
            }
        }
        .padding()
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
                statusText = "Released 🚀"
            }

            // End throw when spin drops (net impact)
            if releaseDetected && gyroMag < flightEndGyro {
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
            maxSpin: maxSpin,
            maxAccel: maxAccel
        )

        sendThrowToPhone(throwData)

        statusText = "Throw Saved ✅"
        resetState()
    }

    // MARK: - Networking
    func sendThrowToPhone(_ throwData: ThrowSummary) {
        guard WCSession.isSupported() else {
            statusText = "Watch Connectivity Unavailable"
            return
        }

        let session = WCSession.default
        session.activate()

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(throwData)
            if let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                session.sendMessage(dictionary, replyHandler: nil) { error in
                    print("Error sending throw data to phone:", error)
                }
            }
        } catch {
            print("Encoding error:", error)
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
    }
}
