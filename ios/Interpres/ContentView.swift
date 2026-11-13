import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var jitEnabled = JITStatus.isEnabled
    @State private var rawFlagsHex = JITStatus.flagsHexString
    @State private var copiedItem: String?
    @State private var isImportingPairing = false
    @State private var pairingImportError: String?
    @State private var hasPairingFile = PairingManager.hasPairingFile

    @ObservedObject private var builtInJIT = BuiltInJIT.shared
    @ObservedObject private var launcher = JITLauncher.shared

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    statusBanner
                    builtInJITSection
                    externalAppsSection
                    diagnosticsSection
                    deviceFooter
                }
                .padding()
            }
            .navigationTitle("Interpres")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $isImportingPairing, allowedContentTypes: [.item]) { result in
                handlePairingImport(result)
            }
            .onReceive(timer) { _ in
                let current = JITStatus.isEnabled
                if jitEnabled != current {
                    jitEnabled = current
                }
                rawFlagsHex = JITStatus.flagsHexString
                hasPairingFile = PairingManager.hasPairingFile
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)
            Text("Mac Translation Layer")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Loads Apple Silicon Mac binaries on iPadOS")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Status Banner
    private var statusBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: jitEnabled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(jitEnabled ? Color.green : Color.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(jitEnabled ? "JIT Enabled" : "JIT Inactive")
                        .font(.title3.bold())
                        .foregroundStyle(jitEnabled ? Color.green : Color.red)

                    Text(jitEnabled
                         ? "Kernel CS_DEBUGGED active. Mac binaries can execute."
                         : "Executable memory restricted. Attach a debugger to enable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(jitEnabled ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(jitEnabled ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Built-in JIT Section (Like Henge)
    private var builtInJITSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Built-in StikJIT", systemImage: "bolt.badge.automatic.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("On-Device")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text("Enable JIT entirely on-device using the built-in helper extension, without switching to external apps (same engine used by Henge).")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Pairing File Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pairing File")
                        .font(.subheadline.bold())
                    Text(hasPairingFile ? "pairingFile.plist loaded" : "No pairing file imported")
                        .font(.caption)
                        .foregroundStyle(hasPairingFile ? Color.green : Color.secondary)
                }
                Spacer()
                Button(hasPairingFile ? "Replace" : "Import") {
                    isImportingPairing = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if hasPairingFile {
                    Button(role: .destructive) {
                        try? PairingManager.deletePairingFile()
                        hasPairingFile = false
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)

            if let error = pairingImportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }

            // Built-in Action Buttons
            HStack(spacing: 12) {
                Button {
                    builtInJIT.enableJIT()
                } label: {
                    HStack {
                        if builtInJIT.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text("Enable JIT Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(builtInJIT.isBusy || !hasPairingFile)

                Button {
                    builtInJIT.prepareDevice()
                } label: {
                    Text("Test DDI")
                        .frame(maxWidth: 80)
                }
                .buttonStyle(.bordered)
                .disabled(builtInJIT.isBusy || !hasPairingFile)
            }

            if let status = builtInJIT.statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: (builtInJIT.isSuccess == true) ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle((builtInJIT.isSuccess == true) ? Color.green : Color.accentColor)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            Text("Tip: Ensure LocalDevVPN tunnel is active if running on iOS 17.4+.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - External Apps Fallback
    private var externalAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("External App Triggers", systemImage: "arrow.up.right.square")
                .font(.headline)
            Text("If you prefer using an external debugger or sideloading tool:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(JITMethod.allCases) { method in
                Button {
                    launcher.trigger(method)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: method.iconName)
                            .font(.title2)
                            .frame(width: 32)
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(method.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(method.description)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            if let status = launcher.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle((launcher.isSuccess == true) ? Color.green : Color.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Diagnostics
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Process Diagnostics", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            VStack(spacing: 8) {
                diagnosticRow(title: "Process ID (PID)", value: "\(JITStatus.processID)", id: "pid")
                diagnosticRow(title: "Bundle ID", value: JITStatus.bundleID, id: "bundle")
                diagnosticRow(title: "csops Status Flags", value: rawFlagsHex, id: "flags")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func diagnosticRow(title: String, value: String, id: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .bold()
            Button {
                UIPasteboard.general.string = value
                copiedItem = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedItem == id { copiedItem = nil }
                }
            } label: {
                Image(systemName: copiedItem == id ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copiedItem == id ? Color.green : Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer
    private var deviceFooter: some View {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return Text("Interpres \(version) · \(UIDevice.current.systemName) \(os)")
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    // MARK: - Helper Methods
    private func handlePairingImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try PairingManager.importPairingFile(from: url)
                hasPairingFile = true
                pairingImportError = nil
            } catch {
                pairingImportError = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            pairingImportError = error.localizedDescription
        }
    }
}
