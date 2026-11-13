import Foundation

// csops is exported by libsystem_kernel but has no public header on iOS.
@_silgen_name("csops")
private func csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

public enum JITStatus {
    public static let CS_OPS_STATUS: UInt32 = 0
    public static let CS_DEBUGGED: UInt32 = 0x1000_0000

    /// Returns the raw csops flags for the current process, or nil if the call failed.
    public static var flags: UInt32? {
        var flags: UInt32 = 0
        let result = csops(getpid(), CS_OPS_STATUS, &flags, MemoryLayout<UInt32>.size)
        return result == 0 ? flags : nil
    }

    /// True once a debugger (StikDebug, SideStore, TrollStore, Xcode) has attached.
    /// From then on the kernel lets this process run code pages that are not signed,
    /// which is what loading a Mac binary needs.
    public static var isEnabled: Bool {
        guard let flags = flags else { return false }
        return (flags & CS_DEBUGGED) != 0
    }

    /// Current process ID.
    public static var processID: pid_t {
        getpid()
    }

    /// Current bundle identifier.
    public static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "dev.interpres.app"
    }

    /// Hex representation of the raw csops flags (e.g. "0x10000000").
    public static var flagsHexString: String {
        if let flags = flags {
            return String(format: "0x%08X", flags)
        } else {
            return "Unavailable"
        }
    }
}
