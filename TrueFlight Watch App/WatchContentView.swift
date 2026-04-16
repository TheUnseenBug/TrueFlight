import SwiftUI
import CoreMotion

struct WatchContentView: View {
    @State private var isRecording = false
    private let motionManager = CMMotionManager()

    var body: some View {
        VStack {
            Text(isRecording ? "Recording..." : "Idle")
                .font(.headline)

            Button(isRecording ? "Stop" : "Start") {
                isRecording ? stopMotion() : startMotion()
                isRecording.toggle()
            }
        }
        .padding()
    }

    func startMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0

        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion else { return }

            let gyro = motion.rotationRate
            let accel = motion.userAcceleration

            print("Gyro z: \(gyro.z)")
            print("Accel x: \(accel.x)")
        }
    }

    func stopMotion() {
        motionManager.stopDeviceMotionUpdates()
    }
}
