#if os(watchOS)
import Foundation
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isActivated: Bool = false
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isCompanionAppInstalled: Bool = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            updateState(session)
        }
    }

    // MARK: - Sending
    func send(message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        // Ensure activation; if not yet activated, queue a background transfer.
        if session.activationState != .activated {
            session.activate()
            session.transferUserInfo(message)
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Watch sendMessage error: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        updateState(session)
        if let error = error {
            print("Watch WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("Watch WCSession activation state: \(activationState.rawValue)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateState(session)
        print("Watch reachability changed: \(session.isReachable)")
    }

    // MARK: - State
    private func updateState(_ session: WCSession = .default) {
        DispatchQueue.main.async {
            self.isActivated = (session.activationState == .activated)
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
        }
    }
}
#endif
