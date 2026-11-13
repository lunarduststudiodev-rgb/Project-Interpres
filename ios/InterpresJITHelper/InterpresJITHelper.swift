import Foundation
import StikJIT

/// The helper process that attaches a debugger to Interpres over the RSD tunnel.
private enum InterpresJITWork {
    static let queue = DispatchQueue(label: "dev.interpres.app.jit-helper")
    private static let lastPortKey = "interpres.lastRSDPort"

    static func handle(_ request: InterpresJITRequest) -> InterpresJITRequest.Response {
        let manager = FileManager.default
        let root = manager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StikJIT", isDirectory: true)
        let paths = DDIPaths.default(in: root)
        var configuration = StikJIT.Configuration.default
        var portNote = ""
        var needsScan = false

        if let rsdPort = request.rsdPort {
            configuration.rsdPort = rsdPort
        } else if request.operation != .resetDDI {
            let lookup = RSDPortResolver.resolve()
            NSLog("[InterpresJIT] RemotePairing port: %@", lookup.detail)
            if let port = lookup.port {
                configuration.rsdPort = port
            } else {
                needsScan = true
            }
            portNote = " [helper port lookup: \(lookup.detail); using \(configuration.rsdPort)]"
        }

        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            if request.operation == .resetDDI {
                try StikJIT.resetCachedDDI(at: paths)
                return .init(success: true, message: "DDI cache reset successfully.", txmPresent: nil)
            }

            guard let pairingData = request.pairingData, !pairingData.isEmpty else {
                throw NSError(domain: "InterpresJITHelper", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No pairing file data provided."])
            }
            let pairingURL = root.appendingPathComponent("pairingFile-\(UUID().uuidString).plist")
            try pairingData.write(to: pairingURL, options: .atomic)
            defer { try? manager.removeItem(at: pairingURL) }

            if needsScan {
                if let port = findRSDPort(pairingFile: pairingURL, base: configuration) {
                    configuration.rsdPort = port
                    portNote += " [port scan: found \(port)]"
                } else {
                    portNote += " [port scan: no RemotePairing port found]"
                }
            }

            switch request.operation {
            case .prepare:
                let readiness = StikJIT.prepareDevice(
                    pairingFile: pairingURL, paths: paths, configuration: configuration,
                    progress: { NSLog("[InterpresJIT] prepare: %@", String(describing: $0)) })
                switch readiness {
                case .ready(let security):
                    return .init(success: true,
                                 message: "Device ready and DDI prepared." + portNote,
                                 txmPresent: security.isTXMPresent)
                case .unreachable(let reason), .preparationFailed(let reason):
                    return .init(success: false, message: reason + portNote, txmPresent: nil)
                @unknown default:
                    return .init(success: false, message: "Unknown readiness state." + portNote, txmPresent: nil)
                }

            case .enable:
                guard let targetPID = request.targetPID else {
                    throw NSError(domain: "InterpresJITHelper", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Target PID not provided."])
                }
                try StikJIT.enableJIT(
                    targetPID: targetPID,
                    pairingFile: pairingURL,
                    ddiPaths: paths,
                    configuration: configuration,
                    script: .universal,
                    forceScript: true,
                    preparationProgress: { NSLog("[InterpresJIT] prepare: %@", String(describing: $0)) },
                    progress: { NSLog("[InterpresJIT] %@", $0) })
                return .init(success: true,
                             message: "JIT successfully enabled for PID \(targetPID)." + portNote,
                             txmPresent: nil)

            case .resetDDI:
                preconditionFailure("Handled above")
            }
        } catch {
            return .init(success: false, message: error.localizedDescription + portNote, txmPresent: nil)
        }
    }

    private static func findRSDPort(pairingFile: URL, base: StikJIT.Configuration) -> UInt16? {
        func works(_ port: UInt16) -> Bool {
            var probe = base
            probe.rsdPort = port
            probe.connectionTimeout = 2
            return (try? StikJIT.isDDIMounted(pairingFile: pairingFile, configuration: probe)) != nil
        }
        let last = UInt16(exactly: UserDefaults.standard.integer(forKey: lastPortKey)) ?? 0
        if last != 0, works(last) { return last }
        let open = RSDPortScanner.openPorts(host: base.deviceAddress)
        guard let port = open.first(where: works) else { return nil }
        UserDefaults.standard.set(Int(port), forKey: lastPortKey)
        return port
    }
}

/// Principal class handling extension requests from the host app.
@objc(InterpresJITHelperHandler)
public final class InterpresJITHelperHandler: NSObject, NSExtensionRequestHandling {
    public func beginRequest(with context: NSExtensionContext) {
        let info = (context.inputItems.first as? NSExtensionItem)?.userInfo
        let data = info?[InterpresJITRequest.itemKey] as? Data

        InterpresJITWork.queue.async {
            let response: InterpresJITRequest.Response
            if let data = data, let request = try? JSONDecoder().decode(InterpresJITRequest.self, from: data) {
                response = InterpresJITWork.handle(request)
            } else {
                response = .init(success: false, message: "Interpres JIT helper received no valid request payload.")
            }

            let item = NSExtensionItem()
            item.userInfo = [InterpresJITRequest.Response.itemKey: (try? JSONEncoder().encode(response)) ?? Data()]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        }
    }
}
