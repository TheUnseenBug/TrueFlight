import Foundation
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isReachable: Bool = false
    @Published var isArmedByPhone: Bool = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    var onArmCommand: ((Bool) -> Void)?

    private override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        guard let session = session else { return }
        session.delegate = self
        session.activate()
    }

    func send(message: [String: Any]) {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // Best-effort background delivery
            _ = try? session.updateApplicationContext(message)
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    // Receive arm/disarm commands from phone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let command = message["command"] as? String {
            let isArmed = command == "arm"
            DispatchQueue.main.async { [weak self] in
                self?.isArmedByPhone = isArmed
                self?.onArmCommand?(isArmed)
            }
        }
    }
}
