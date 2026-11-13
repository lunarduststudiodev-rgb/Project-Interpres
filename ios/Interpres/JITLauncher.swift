import Foundation
import UIKit

/// Available JIT attachment providers and schemes.
public enum JITMethod: String, CaseIterable, Identifiable {
    case stikDebug = "StikDebug"
    case trollStore = "TrollStore"
    case sideStore = "SideStore"

    public var id: String { rawValue }

    public var scheme: String {
        switch self {
        case .stikDebug:
            return "stikjit"
        case .trollStore:
            return "apple-magnifier"
        case .sideStore:
            return "sidestore"
        }
    }

    public var title: String {
        rawValue
    }

    public var description: String {
        switch self {
        case .stikDebug:
            return "Local loopback VPN debugger (stikjit://)"
        case .trollStore:
            return "TrollStore helper (apple-magnifier://)"
        case .sideStore:
            return "SideStore sideload manager"
        }
    }

    public var iconName: String {
        switch self {
        case .stikDebug:
            return "ladybug.fill"
        case .trollStore:
            return "wand.and.stars"
        case .sideStore:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    public func url(bundleID: String = JITStatus.bundleID, pid: pid_t = JITStatus.processID) -> URL? {
        let encodedBundleID = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        switch self {
        case .stikDebug:
            // stikjit://enable-jit?bundle-id=<id>&pid=<pid>
            return URL(string: "stikjit://enable-jit?bundle-id=\(encodedBundleID)&pid=\(pid)")
        case .trollStore:
            // apple-magnifier://enable-jit?bundle-id=<id>
            return URL(string: "apple-magnifier://enable-jit?bundle-id=\(encodedBundleID)")
        case .sideStore:
            return URL(string: "sidestore://")
        }
    }

    public var isAvailableOnDevice: Bool {
        guard let url = url() else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// Observable coordinator that handles JIT trigger requests and publishes status updates.
@MainActor
public final class JITLauncher: ObservableObject {
    public static let shared = JITLauncher()

    @Published public private(set) var isTriggering: Bool = false
    @Published public private(set) var lastTriggeredMethod: JITMethod?
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var isSuccess: Bool?

    public init() {}

    /// Automatically resolves the best way to enable JIT with a single tap, matching Henge.
    public func autoEnable() {
        self.isTriggering = true
        self.statusMessage = "Enabling JIT..."
        self.isSuccess = nil

        // 1. If process can grant its own JIT (TrollStore dynamic-codesigning, MAP_JIT)
        if SelfJITGrant.canSelfGrant {
            self.isTriggering = false
            self.isSuccess = true
            self.statusMessage = "JIT enabled directly via MAP_JIT."
            return
        }

        // 2. If Built-in StikJIT is ready (pairing file + LocalDevVPN + helper)
        if PairingManager.hasPairingFile && BuiltInJIT.isHelperInstalled && LocalDevVPN.isConnected {
            BuiltInJIT.shared.enableJIT()
            self.isTriggering = false
            return
        }

        // 3. Try StikDebug URL scheme
        if let stikUrl = JITMethod.stikDebug.url(), UIApplication.shared.canOpenURL(stikUrl) {
            trigger(JITMethod.stikDebug)
            return
        }

        // 4. Try TrollStore URL scheme
        if let trollUrl = JITMethod.trollStore.url(), UIApplication.shared.canOpenURL(trollUrl) {
            trigger(JITMethod.trollStore)
            return
        }

        // 5. Try opening StikDebug without canOpenURL check (container apps often block canOpenURL queries)
        if let stikUrl = JITMethod.stikDebug.url() {
            UIApplication.shared.open(stikUrl, options: [:]) { [weak self] success in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if success {
                        self.isTriggering = false
                        self.isSuccess = true
                        self.statusMessage = "Opened StikDebug. Waiting for debugger to attach..."
                    } else {
                        // 6. Try TrollStore fallback
                        if let trollUrl = JITMethod.trollStore.url() {
                            UIApplication.shared.open(trollUrl, options: [:]) { [weak self] tSuccess in
                                Task { @MainActor [weak self] in
                                    guard let self = self else { return }
                                    if tSuccess {
                                        self.isTriggering = false
                                        self.isSuccess = true
                                        self.statusMessage = "Opened TrollStore. Waiting for attach..."
                                    } else {
                                        // 7. Try SideStore
                                        if let sideStoreUrl = URL(string: "sidestore://") {
                                            UIApplication.shared.open(sideStoreUrl, options: [:]) { [weak self] sSuccess in
                                                Task { @MainActor [weak self] in
                                                    guard let self = self else { return }
                                                    self.isTriggering = false
                                                    if sSuccess {
                                                        self.statusMessage = "Opened SideStore: Long-press Interpres in My Apps and tap Enable JIT."
                                                    } else {
                                                        self.isSuccess = false
                                                        self.statusMessage = "No JIT provider found. Install StikDebug or import a pairing file for Built-in JIT."
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Trigger JIT attachment for a specific provider via UIApplication.shared.open.
    public func trigger(_ method: JITMethod) {
        guard let url = method.url() else {
            self.statusMessage = "Error: Failed to construct URL for \(method.title)."
            self.isSuccess = false
            return
        }

        self.isTriggering = true
        self.lastTriggeredMethod = method
        self.statusMessage = "Opening \(method.title)..."
        self.isSuccess = nil

        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isTriggering = false
                self.isSuccess = success
                if success {
                    if method == .sideStore {
                        self.statusMessage = "Opened SideStore: Long-press Interpres in My Apps and tap Enable JIT."
                    } else {
                        self.statusMessage = "Handoff to \(method.title) sent. Waiting for debugger to attach..."
                    }
                } else {
                    self.statusMessage = "Could not open \(method.title) (\(method.scheme)://). Verify that \(method.title) is installed."
                }
            }
        }
    }

    public func clearStatus() {
        self.statusMessage = nil
        self.isSuccess = nil
        self.lastTriggeredMethod = nil
    }
}
