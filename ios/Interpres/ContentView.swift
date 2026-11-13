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
                    sideStoreGuideCard
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

                    if jitEnabled {
                        Text(isKernelDebugged
                             ? "Kernel CS_DEBUGGED active. Mac binaries can execute."
                             : "Dynamic codesigning active (MAP_JIT self-granted).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Executable memory restricted. Attach a debugger to enable.")
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

            Text("Like Henge, Interpres uses an embedded helper extension to mount the Developer Disk Image and attach debugserver on-device without switching apps.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Checklist requirements
            VStack(spacing: 8) {
                // 1. Pairing File
                HStack {
                    Image(systemName: hasPairingFile ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(hasPairingFile ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1. Pairing File")
                            .font(.subheadline.bold())
                        Text(hasPairingFile ? "pairingFile.plist loaded" : "Tap Import to select pairingFile.plist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(hasPairingFile ? "Replace" : "Import") {
                        isImportingPairing = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)

                // 2. LocalDevVPN
                HStack {
                    Image(systemName: isVpnConnected ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(isVpnConnected ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2. LocalDevVPN Loopback")
                            .font(.subheadline.bold())
                        Text(isVpnConnected ? "Tunnel active (10.7.0.0/16)" : "Needs LocalDevVPN connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isVpnConnected ? "Connected" : (LocalDevVPN.isInstalled ? "Connect" : "Get VPN")) {
                        LocalDevVPN.open()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isVpnConnected)
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)

                // 3. Helper Extension
                HStack {
                    Image(systemName: isHelperInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(isHelperInstalled ? Color.green : Color.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("3. JIT Helper Extension")
                            .font(.subheadline.bold())
                        Text(isHelperInstalled ? "PlugIns/InterpresJITHelper.appex present" : "Helper stripped by sideloader (use SideStore below)")
                            .font(.caption)
                            .foregroundStyle(isHelperInstalled ? Color.secondary : Color.red)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }

            // Error display
            if let error = builtInJIT.lastError ?? pairingImportError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .padding(.top, 2)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Trigger Buttons
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
                .disabled(builtInJIT.isBusy || !hasPairingFile || !isHelperInstalled)

                Button {
                    builtInJIT.prepareDevice()
                } label: {
                    Text("Test DDI")
                        .frame(maxWidth: 80)
                }
                .buttonStyle(.bordered)
                .disabled(builtInJIT.isBusy || !hasPairingFile || !isHelperInstalled)
            }

            if let status = builtInJIT.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle((builtInJIT.isSuccess == true) ? Color.green : Color.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - SideStore Direct Guide Card
    private var sideStoreGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("SideStore User? (1-Tap Sideload JIT)", systemImage: "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.primary)
                Spacer()
            }

            Text("SideStore handles JIT natively without needing LocalDevVPN or extra pairing files:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Connect your **SideStore VPN** in iOS Settings.")
                Text("2. Open **SideStore** and go to **My Apps**.")
                Text("3. **Long-press on Interpres** and tap **Enable JIT**.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)

            Button {
                if let url = URL(string: "sidestore://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open SideStore App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - External Apps Fallback
    private var externalAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Other External Triggers", systemImage: "arrow.up.right.square")
                .font(.headline)

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
                diagnosticRow(title: "Kernel CS_DEBUGGED", value: isKernelDebugged ? "YES (0x10000000)" : "NO", id: "debugged")
                diagnosticRow(title: "Self-Grant (MAP_JIT)", value: SelfJITGrant.canSelfGrant ? "Available" : "No", id: "mapjit")
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
