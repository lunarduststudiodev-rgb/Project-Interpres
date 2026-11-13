import Foundation
import UIKit
import Darwin

/// Helper to detect and connect LocalDevVPN (the loopback VPN required for on-device JIT).
public enum LocalDevVPN {
    public static let appStoreURL = URL(string: "https://apps.apple.com/us/app/localdevvpn/id6755608044")!
    public static let connectURL = URL(string: "localdevvpn://enable?scheme=interpres")!
    public static let probeURL = URL(string: "localdevvpn://")!

    /// True if LocalDevVPN app is installed on this device.
    public static var isInstalled: Bool {
        UIApplication.shared.canOpenURL(probeURL)
    }

    /// Whether the LocalDevVPN tunnel is active: an interface with an address in 10.7.0.0/16.
    public static var isConnected: Bool {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return false }
        defer { freeifaddrs(list) }

        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = p.pointee
            guard (ifa.ifa_flags & UInt32(IFF_UP)) != 0,
                  let sa = ifa.ifa_addr,
                  sa.pointee.sa_family == UInt8(AF_INET) else { continue }

            let ip = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            // 10.7.0.0/16 has top 16 bits == 0x0a07
            if ip >> 16 == 0x0a07, String(cString: ifa.ifa_name).hasPrefix("utun") {
                return true
            }
        }
        return false
    }

    /// One-tap action: opens LocalDevVPN to connect and return, or opens App Store to install it.
    @MainActor
    public static func open() {
        if isInstalled {
            UIApplication.shared.open(connectURL)
        } else {
            UIApplication.shared.open(appStoreURL)
        }
    }
}
