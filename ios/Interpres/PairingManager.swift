import Foundation

/// Manages loading, storing, and validating the device pairing file.
public enum PairingManager {
    public static var stikJITDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("StikJIT", isDirectory: true)
    }

    public static var pairingFileURL: URL {
        stikJITDirectory.appendingPathComponent("pairingFile.plist")
    }

    public static var hasPairingFile: Bool {
        FileManager.default.fileExists(atPath: pairingFileURL.path)
    }

    public static var pairingData: Data? {
        try? Data(contentsOf: pairingFileURL)
    }

    /// Import and validate a pairing file from a security-scoped URL (e.g. from UIDocumentPicker).
    public static func importPairingFile(from url: URL) throws {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw NSError(domain: "InterpresPairing", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The selected file is empty."])
        }

        // Validate that it is a readable property list
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            throw NSError(domain: "InterpresPairing", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "The selected file is not a valid property list (.plist)."])
        }

        // Check for required pairing keys or standard format
        if dict["identifier"] == nil && dict["RootKey"] == nil && dict["DeviceCertificate"] == nil {
            throw NSError(domain: "InterpresPairing", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The file does not appear to be an Apple RemotePairing or lockdown pairing file."])
        }

        try FileManager.default.createDirectory(at: stikJITDirectory, withIntermediateDirectories: true)
        try data.write(to: pairingFileURL, options: .atomic)
    }

    public static func deletePairingFile() throws {
        if hasPairingFile {
            try FileManager.default.removeItem(at: pairingFileURL)
        }
    }
}
