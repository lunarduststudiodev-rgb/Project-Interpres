import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var jitEnabled = JITStatus.isEnabled
    @State private var isKernelDebugged = JITStatus.isKernelDebugged
    @State private var rawFlagsHex = JITStatus.flagsHexString
    @State private var copiedItem: String?
    @State private var isImportingPairing = false
    @State private var pairingImportError: String?
    @State private var hasPairingFile = PairingManager.hasPairingFile
    @State private var isVpnConnected = LocalDevVPN.isConnected
    @State private var isHelperInstalled = BuiltInJIT.isHelperInstalled
    @State private var showAdvanced = false

    @ObservedObject private var builtInJIT = BuiltInJIT.shared
    @ObservedObject private var launcher = JITLauncher.shared

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headerView
                    statusBanner
                    primaryActionButton
                    troubleshootingHint
                    advancedSectionToggle
                    if showAdvanced {
                        advancedOptionsSection
                    }
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
                jitEnabled = JITStatus.isEnabled
                isKernelDebugged = JITStatus.isKernelDebugged
                rawFlagsHex = JITStatus.flagsHexString
                hasPairingFile = PairingManager.hasPairingFile
                isVpnConnected = LocalDevVPN.isConnected
                isHelperInstalled = BuiltInJIT.isHelperInstalled
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
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
        HStack(spacing: 14) {
            Image(systemName: jitEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(jitEnabled ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 3) {
                Text(jitEnabled ? "JIT is On" : "JIT is Off")
                    .font(.title3.bold())
                    .foregroundStyle(jitEnabled ? Color.green : Color.red)

                if jitEnabled {
                    Text(isKernelDebugged
                         ? "Kernel CS_DEBUGGED active. Mac binaries can execute."
                         : "Dynamic codesigning active (MAP_JIT self-granted).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Needs executable memory to run Mac apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    // MARK: - 1-Click Turn On JIT (Like Henge)
    private var primaryActionButton: some View {
        VStack(spacing: 12) {
            Button {
                launcher.autoEnable()
            } label: {
                HStack(spacing: 10) {
                    if launcher.isTriggering || builtInJIT.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: jitEnabled ? "checkmark.seal.fill" : "bolt.fill")
                    }
                    Text(jitEnabled ? "JIT Already Enabled" : "Turn On JIT")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(jitEnabled || launcher.isTriggering || builtInJIT.isBusy)

            if let message = launcher.statusMessage ?? builtInJIT.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(launcher.isSuccess == true ? Color.green : Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Troubleshooting Hint
    private var troubleshootingHint: some View {
        Group {
            if !jitEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("If tapping 'Turn On JIT' asks for an app:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("• **SideStore**: Open SideStore → My Apps → Long-press Interpres → tap **Enable JIT**.")
                    Text("• **StikDebug**: Sideload StikDebug, open it once, and tap Turn On JIT again.")
                    Text("• **TrollStore**: JIT attaches automatically via URL scheme.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Advanced Section Toggle
    private var advancedSectionToggle: some View {
        Button {
            withAnimation { showAdvanced.toggle() }
        } label: {
            HStack {
                Text(showAdvanced ? "Hide Advanced JIT Setup" : "Show Advanced / Built-in JIT Setup")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        VStack(spacing: 16) {
            // Built-in StikJIT Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Built-in StikJIT (No PC / No App Switch)", systemImage: "bolt.badge.automatic.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                Text("Requires a pairing file and LocalDevVPN connected:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: hasPairingFile ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(hasPairingFile ? Color.green : Color.orange)
                    Text(hasPairingFile ? "Pairing file loaded" : "No pairing file")
                        .font(.caption)
                    Spacer()
                    Button(hasPairingFile ? "Replace" : "Import") {
                        isImportingPairing = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    Image(systemName: isVpnConnected ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(isVpnConnected ? Color.green : Color.orange)
                    Text(isVpnConnected ? "LocalDevVPN Connected" : "LocalDevVPN Disconnected")
                        .font(.caption)
                    Spacer()
                    Button(isVpnConnected ? "Connected" : (LocalDevVPN.isInstalled ? "Connect" : "Get VPN")) {
                        LocalDevVPN.open()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isVpnConnected)
                }

                Button {
                    builtInJIT.enableJIT()
                } label: {
                    Text("Enable via Built-in Helper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasPairingFile || !isHelperInstalled || builtInJIT.isBusy)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)

            // Manual External Triggers
            VStack(alignment: .leading, spacing: 10) {
                Label("Manual App Triggers", systemImage: "arrow.up.right.square")
                    .font(.headline)

                ForEach(JITMethod.allCases) { method in
                    Button {
                        launcher.trigger(method)
                    } label: {
                        HStack {
                            Image(systemName: method.iconName)
                                .frame(width: 24)
                                .foregroundStyle(Color.accentColor)
                            Text(method.title)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Diagnostics
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Diagnostics", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            VStack(spacing: 6) {
                diagnosticRow(title: "PID", value: "\(JITStatus.processID)", id: "pid")
                diagnosticRow(title: "Bundle ID", value: JITStatus.bundleID, id: "bundle")
                diagnosticRow(title: "Kernel CS_DEBUGGED", value: isKernelDebugged ? "YES (0x10000000)" : "NO", id: "debugged")
                diagnosticRow(title: "Self-Grant (MAP_JIT)", value: SelfJITGrant.canSelfGrant ? "YES" : "NO", id: "mapjit")
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
        .padding(.vertical, 2)
    }

    // MARK: - Footer
    private var deviceFooter: some View {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return Text("Interpres \(version) · \(UIDevice.current.systemName) \(os)")
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .padding(.top, 4)
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
