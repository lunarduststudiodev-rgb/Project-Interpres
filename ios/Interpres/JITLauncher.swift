import Foundation
import UIKit

/// Available JIT attachment providers and schemes.
public enum JITMethod: String, CaseIterable, Identifiable {
    case stikDebug = "StikDebug"
    case sideStore = "SideStore"
    case trollStore = "TrollStore"

    public var id: String { rawValue }

    public var scheme: String {
        switch self {
        case .stikDebug:
            return "stikjit"
        case .sideStore:
            return "sidestore"
        case .trollStore:
            return "apple-magnifier"
        }
    }

    public var title: String {
        rawValue
    }

    public var description: String {
        switch self {
        case .stikDebug:
            return "Local loopback debugger (stikjit://)"
        case .sideStore:
            return "SideStore sideload manager (sidestore://)"
        case .trollStore:
            return "TrollStore helper (requires TrollStore installed)"
        }
    }

    public var iconName: String {
        switch self {
        case .stikDebug:
            return "ladybug.fill"
        case .sideStore:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .trollStore:
            return "wand.and.stars"
        }
    }

    public func url(bundleID: String = JITStatus.bundleID, pid: pid_t = JITStatus.processID) -> URL? {
        let encodedBundleID = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        switch self {
        case .stikDebug:
            return URL(string: "stikjit://enable-jit?bundle-id=\(encodedBundleID)&pid=\(pid)")
        case .sideStore:
            return URL(string: "sidestore://")
        case .trollStore:
            return URL(string: "apple-magnifier://enable-jit?bundle-id=\(encodedBundleID)")
        }
    }

    public var isAvailableOnDevice: Bool {
        switch self {
        case .stikDebug:
            return UIApplication.shared.canOpenURL(URL(string: "stikjit://")!)
        case .sideStore:
            return UIApplication.shared.canOpenURL(URL(string: "sidestore://")!)
        case .trollStore:
            // apple-magnifier:// is Apple's built-in Magnifier camera on iOS.
            // ONLY report available if TrollStore marker file actually exists!
            return Self.isTrollStoreActuallyInstalled
        }
    }

    /// Whether this app was actually installed by TrollStore (which creates a _TrollStore marker).
    public static var isTrollStoreActuallyInstalled: Bool {
        guard let containerURL = Bundle.main.bundleURL.deletingLastPathComponent() as URL? else { return false }
        let marker = containerURL.appendingPathComponent("_TrollStore")
        return FileManager.default.fileExists(atPath: marker.path)
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

        // 1. Direct self-grant (MAP_JIT / jailbreak)
        if SelfJITGrant.canSelfGrant {
            self.isTriggering = false
            self.isSuccess = true
            self.statusMessage = "JIT enabled directly via MAP_JIT."
            return
        }

        // 2. StikDebug (stikjit://) - this is what Henge uses for 1-click on-device JIT!
        let stikURL = JITMethod.stikDebug.url()!
        if UIApplication.shared.canOpenURL(URL(string: "stikjit://")!) {
            trigger(JITMethod.stikDebug)
            return
        }

        // 3. Built-in StikJIT (if pairing file is loaded and VPN connected)
        if PairingManager.hasPairingFile && BuiltInJIT.isHelperInstalled && LocalDevVPN.isConnected {
            BuiltInJIT.shared.enableJIT()
            self.isTriggering = false
            return
        }

        // 4. Try opening stikjit:// directly even if canOpenURL was restricted
        UIApplication.shared.open(stikURL, options: [:]) { [weak self] stikSuccess in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if stikSuccess {
                    self.isTriggering = false
                    self.isSuccess = true
                    self.statusMessage = "Opened StikDebug. Attaching JIT..."
                    return
                }

                // 5. Try SideStore (sidestore://)
                if let sideStoreURL = URL(string: "sidestore://"), UIApplication.shared.canOpenURL(sideStoreURL) {
                    UIApplication.shared.open(sideStoreURL, options: [:]) { sSuccess in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.isTriggering = false
                            if sSuccess {
                                self.statusMessage = "Opened SideStore: In 'My Apps', long-press Interpres → Enable JIT."
                            } else {
                                self.isSuccess = false
                                self.statusMessage = "Please open SideStore or StikDebug to attach JIT."
                            }
                        }
                    }
                    return
                }

                // 6. Only check TrollStore if verified marker file exists (never open Apple Magnifier camera!)
                if JITMethod.isTrollStoreActuallyInstalled, let trollURL = JITMethod.trollStore.url() {
                    UIApplication.shared.open(trollURL, options: [:]) { tSuccess in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.isTriggering = false
                            if tSuccess {
                                self.statusMessage = "Opened TrollStore. Attaching JIT..."
                            }
                        }
                    }
                    return
                }

                // 7. Nothing answered
                self.isTriggering = false
                self.isSuccess = false
                self.statusMessage = "StikDebug not found. Open SideStore → My Apps → Long-press Interpres → Enable JIT."
            }
        }
    }

    /// Trigger JIT attachment for a specific provider via UIApplication.shared.open.
    public func trigger(_ method: JITMethod) {
        // Guard against opening Apple Magnifier camera if TrollStore is not installed
        if method == .trollStore && !JITMethod.isTrollStoreActuallyInstalled {
            self.isTriggering = false
            self.isSuccess = false
            self.statusMessage = "TrollStore is not installed. (apple-magnifier would open camera)."
            return
        }

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
