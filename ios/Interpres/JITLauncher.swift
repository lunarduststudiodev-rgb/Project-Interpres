import Foundation
import UIKit

/// Available JIT attachment providers and schemes.
public enum JITMethod: String, CaseIterable, Identifiable {
    case stikDebug = "StikDebug"
    case sideStore = "SideStore"
    case trollStore = "TrollStore"

    public var id: String { rawValue }

    /// URL scheme without the trailing ://
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

    /// Display title for the method.
    public var title: String {
        rawValue
    }

    /// Short technical description of the scheme and mechanism.
    public var description: String {
        switch self {
        case .stikDebug:
            return "Local loopback VPN debugger"
        case .sideStore:
            return "WireGuard VPN on-device JIT"
        case .trollStore:
            return "Root helper JIT entitlement"
        }
    }

    /// SF Symbol icon name.
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

    /// Generates the deep link URL for handoff to the JIT provider.
    public func url(bundleID: String = JITStatus.bundleID, pid: pid_t = JITStatus.processID) -> URL? {
        let encodedBundleID = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        switch self {
        case .stikDebug:
            // stikjit://enable-jit?bundle-id=<id>&pid=<pid>
            return URL(string: "stikjit://enable-jit?bundle-id=\(encodedBundleID)&pid=\(pid)")
        case .sideStore:
            // sidestore://sidejit?bundle-id=<id>
            return URL(string: "sidestore://sidejit?bundle-id=\(encodedBundleID)")
        case .trollStore:
            // apple-magnifier://enable-jit?bundle-id=<id>
            return URL(string: "apple-magnifier://enable-jit?bundle-id=\(encodedBundleID)")
        }
    }

    /// Checks if an app registered to handle this URL scheme is installed.
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

    /// Trigger JIT attachment for a given method via UIApplication.shared.open.
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
                    self.statusMessage = "Handoff to \(method.title) sent. Waiting for debugger to attach..."
                } else {
                    self.statusMessage = "Could not open \(method.title) (\(method.scheme)://). Verify that \(method.title) is installed."
                }
            }
        }
    }

    /// Async counterpart for triggering JIT attachment.
    @discardableResult
    public func triggerAsync(_ method: JITMethod) async -> Bool {
        guard let url = method.url() else {
            self.statusMessage = "Error: Failed to construct URL for \(method.title)."
            self.isSuccess = false
            return false
        }

        self.isTriggering = true
        self.lastTriggeredMethod = method
        self.statusMessage = "Opening \(method.title)..."
        self.isSuccess = nil

        let success = await UIApplication.shared.open(url, options: [:])
        self.isTriggering = false
        self.isSuccess = success
        if success {
            self.statusMessage = "Handoff to \(method.title) sent. Waiting for debugger to attach..."
        } else {
            self.statusMessage = "Could not open \(method.title) (\(method.scheme)://). Verify that \(method.title) is installed."
        }
        return success
    }

    /// Resets the current status message and state.
    public func clearStatus() {
        self.statusMessage = nil
        self.isSuccess = nil
        self.lastTriggeredMethod = nil
    }
}
