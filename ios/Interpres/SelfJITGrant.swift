import Foundation
import Darwin

/// Tests and claims JIT memory self-grant routes (TrollStore dynamic-codesigning, jailbreaks).
public enum SelfJITGrant {
    /// True if the process has dynamic-codesigning entitlement and MAP_JIT succeeds.
    public static var canSelfGrant: Bool {
        // Allocate a test page with MAP_JIT
        let size = 16384
        let ptr = mmap(nil, size, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0)
        if ptr != MAP_FAILED {
            munmap(ptr, size)
            return true
        }
        return false
    }

    /// True if running on a jailbroken device where /var/jb exists.
    public static var isJailbroken: Bool {
        access("/var/jb", F_OK) == 0
    }
}
