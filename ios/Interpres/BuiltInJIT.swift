import Foundation
import UIKit

@objc private protocol NSExtensionClassShim {
    @objc(extensionWithIdentifier:error:)
    func `extension`(withIdentifier identifier: String) throws -> AnyObject
}

@objc private protocol NSExtensionShim {
    @objc(beginExtensionRequestWithInputItems:completion:)
    func beginExtensionRequest(withInputItems items: [Any], completion: @escaping (NSUUID?) -> Void)
    @objc(pidForRequestIdentifier:)
    func pid(forRequestIdentifier identifier: NSUUID) -> Int32
    @objc(setRequestCompletionBlock:)
    func setRequestCompletionBlock(_ block: @escaping (NSUUID?, [Any]?) -> Void)
    @objc(setRequestCancellationBlock:)
    func setRequestCancellationBlock(_ block: @escaping (NSUUID?, NSError?) -> Void)
    @objc(setRequestInterruptionBlock:)
    func setRequestInterruptionBlock(_ block: @escaping (NSUUID?) -> Void)
}

/// Host coordinator for the built-in JIT helper app extension (`PlugIns/InterpresJITHelper.appex`).
@MainActor
public final class BuiltInJIT: ObservableObject {
    public static let shared = BuiltInJIT()

    public static let helperFileName = "InterpresJITHelper.appex"

    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var lastError: String?
    @Published public private(set) var isSuccess: Bool?

    private var activeRequest: HelperRequest?

    public init() {}

    /// The helper's bundle identifier in this installation.
    public static var helperIdentifier: String? {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent(helperFileName) else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    /// True if the helper is present in the bundle.
    public static var isHelperInstalled: Bool {
        helperIdentifier != nil
    }

    /// Enable JIT using the built-in helper extension and the imported pairing file.
    public func enableJIT() {
        guard !isBusy else { return }

        guard let pairingData = PairingManager.pairingData else {
            self.lastError = "No pairing file found. Please import a pairing file first."
            self.statusMessage = "Missing pairing file"
            self.isSuccess = false
            return
        }

        guard let helperId = Self.helperIdentifier else {
            self.lastError = "Interpres JIT helper extension is missing from the bundle."
            self.statusMessage = "Helper not found"
            self.isSuccess = false
            return
        }

        self.isBusy = true
        self.statusMessage = "Launching built-in JIT helper..."
        self.lastError = nil
        self.isSuccess = nil

        let request = InterpresJITRequest.enable(targetPID: getpid(), pairingData: pairingData)

        send(request, helperId: helperId) { [weak self] result in
            guard let self = self else { return }
            self.isBusy = false
            switch result {
            case .success(let response):
                self.isSuccess = response.success
                self.statusMessage = response.message
                if !response.success {
                    self.lastError = response.message
                }
            case .failure(let error):
                self.isSuccess = false
                self.lastError = error.localizedDescription
                self.statusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }

    /// Test / prepare connection with the device and DDI.
    public func prepareDevice() {
        guard !isBusy else { return }

        guard let pairingData = PairingManager.pairingData else {
            self.lastError = "No pairing file found. Please import a pairing file first."
            self.statusMessage = "Missing pairing file"
            self.isSuccess = false
            return
        }

        guard let helperId = Self.helperIdentifier else {
            self.lastError = "Interpres JIT helper extension is missing from the bundle."
            self.statusMessage = "Helper not found"
            self.isSuccess = false
            return
        }

        self.isBusy = true
        self.statusMessage = "Preparing device and checking DDI..."
        self.lastError = nil
        self.isSuccess = nil

        let request = InterpresJITRequest.prepare(pairingData: pairingData)

        send(request, helperId: helperId) { [weak self] result in
            guard let self = self else { return }
            self.isBusy = false
            switch result {
            case .success(let response):
                self.isSuccess = response.success
                self.statusMessage = response.message
                if !response.success {
                    self.lastError = response.message
                }
            case .failure(let error):
                self.isSuccess = false
                self.lastError = error.localizedDescription
                self.statusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func send(_ request: InterpresJITRequest,
                      helperId: String,
                      completion: @escaping (Result<InterpresJITRequest.Response, Error>) -> Void) {
        if NSClassFromString("NSExtension") == nil {
            dlopen("/System/Library/Frameworks/ExtensionFoundation.framework/ExtensionFoundation", RTLD_NOW)
        }
        guard let extensionClass = NSClassFromString("NSExtension") else {
            completion(.failure(NSError(domain: "BuiltInJIT", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "iOS ExtensionFoundation is unavailable."])))
            return
        }

        let factory = unsafeBitCast(extensionClass as AnyObject, to: NSExtensionClassShim.self)
        let found: AnyObject
        do {
            found = try factory.extension(withIdentifier: helperId)
        } catch {
            completion(.failure(NSError(domain: "BuiltInJIT", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "Helper could not be found: \(error.localizedDescription)"])))
            return
        }

        guard let data = try? JSONEncoder().encode(request) else {
            completion(.failure(NSError(domain: "BuiltInJIT", code: 3,
                                        userInfo: [NSLocalizedDescriptionKey: "Could not encode request payload."])))
            return
        }

        let helper = HelperRequest(extension: found, completion: completion)
        self.activeRequest = helper
        helper.begin(data: data)
    }
}

@MainActor
private final class HelperRequest {
    private let shim: NSExtensionShim
    private let `extension`: AnyObject
    private var completion: ((Result<InterpresJITRequest.Response, Error>) -> Void)?

    init(extension found: AnyObject, completion: @escaping (Result<InterpresJITRequest.Response, Error>) -> Void) {
        self.extension = found
        self.shim = unsafeBitCast(found, to: NSExtensionShim.self)
        self.completion = completion
    }

    func begin(data: Data) {
        shim.setRequestCompletionBlock { [weak self] _, items in
            let info = (items?.first as? NSExtensionItem)?.userInfo
            let payload = info?[InterpresJITRequest.Response.itemKey] as? Data
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.returned(payload) } }
        }
        shim.setRequestCancellationBlock { [weak self] _, error in
            let msg = error?.localizedDescription ?? "Request was cancelled"
            DispatchQueue.main.async { MainActor.assumeIsolated {
                self?.end(.failure(NSError(domain: "BuiltInJIT", code: 4, userInfo: [NSLocalizedDescriptionKey: msg])))
            } }
        }
        shim.setRequestInterruptionBlock { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                self?.end(.failure(NSError(domain: "BuiltInJIT", code: 5, userInfo: [NSLocalizedDescriptionKey: "Helper process interrupted unexpectedly."])))
            } }
        }

        let item = NSExtensionItem()
        item.userInfo = [InterpresJITRequest.itemKey: data]
        shim.beginExtensionRequest(withInputItems: [item]) { _ in }
    }

    private func returned(_ payload: Data?) {
        guard let payload = payload,
              let response = try? JSONDecoder().decode(InterpresJITRequest.Response.self, from: payload) else {
            end(.failure(NSError(domain: "BuiltInJIT", code: 6, userInfo: [NSLocalizedDescriptionKey: "No response from JIT helper."])))
            return
        }
        end(.success(response))
    }

    private func end(_ result: Result<InterpresJITRequest.Response, Error>) {
        guard let completion = self.completion else { return }
        self.completion = nil
        completion(result)
    }
}
