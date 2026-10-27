import WatchConnectivity

/// The slice of WCSession that WatchConnectivityHandler uses (second-audit D2a).
///
/// Production injects `WCSession.default`; tests inject an in-memory fake so the
/// priority→transport mapping and the replies to the watch's requests can be
/// asserted without a paired watch.
protocol WatchSessionProtocol: AnyObject {
    /// `WCSession.isSupported()` is a class method; this asks it of an instance,
    /// so a fake can answer.
    var isSupported: Bool { get }
    var delegate: WCSessionDelegate? { get set }
    func activate()
    var isReachable: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)?,
                     errorHandler: ((Error) -> Void)?)
    func updateApplicationContext(_ applicationContext: [String: Any]) throws
}

extension WCSession: WatchSessionProtocol {
    var isSupported: Bool { WCSession.isSupported() }
}
