import Foundation

// csops is exported by libsystem_kernel but has no public header on iOS.
@_silgen_name("csops")
private func csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

enum JITStatus {
    private static let CS_OPS_STATUS: UInt32 = 0
    private static let CS_DEBUGGED: UInt32 = 0x1000_0000

    /// True once a debugger (StikDebug, SideStore, Xcode) has attached. From then
    /// on the kernel lets this process run code pages that are not signed, which
    /// is what loading a Mac binary needs.
    static var isEnabled: Bool {
        var flags: UInt32 = 0
        let result = csops(getpid(), CS_OPS_STATUS, &flags, MemoryLayout<UInt32>.size)
        return result == 0 && (flags & CS_DEBUGGED) != 0
    }
}
