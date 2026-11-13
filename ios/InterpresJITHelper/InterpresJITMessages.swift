import Foundation

/// Codable messages shared between Interpres and its JIT helper extension.
/// Compiled into both the main app and InterpresJITHelper targets.
public struct InterpresJITRequest: Codable, Sendable {
    public static let itemKey = "interpres-jit-request"

    public enum Operation: String, Codable, Sendable {
        /// Prepare device: verify LocalDevVPN and prepare Developer Disk Image.
        case prepare
        /// Attach debugger to targetPID and enable JIT.
        case enable
        /// Reset cached DDI.
        case resetDDI
    }

    public let operation: Operation
    public let targetPID: Int32?
    public let pairingData: Data?
    public let rsdPort: UInt16?

    public static func prepare(pairingData: Data, rsdPort: UInt16? = nil) -> InterpresJITRequest {
        InterpresJITRequest(operation: .prepare, targetPID: nil, pairingData: pairingData, rsdPort: rsdPort)
    }

    public static func enable(targetPID: Int32, pairingData: Data, rsdPort: UInt16? = nil) -> InterpresJITRequest {
        InterpresJITRequest(operation: .enable, targetPID: targetPID, pairingData: pairingData, rsdPort: rsdPort)
    }

    public static var resetDDI: InterpresJITRequest {
        InterpresJITRequest(operation: .resetDDI, targetPID: nil, pairingData: nil, rsdPort: nil)
    }

    public struct Response: Codable, Sendable {
        public static let itemKey = "interpres-jit-response"
        public let success: Bool
        public let message: String
        public let txmPresent: Bool?

        public init(success: Bool, message: String, txmPresent: Bool? = nil) {
            self.success = success
            self.message = message
            self.txmPresent = txmPresent
        }
    }
}
