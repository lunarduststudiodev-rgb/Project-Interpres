import SwiftUI

struct ContentView: View {
    @StateObject private var launcher = JITLauncher.shared
    @State private var jitEnabled: Bool = JITStatus.isEnabled
    @State private var rawFlags: String = JITStatus.flagsHexString
    @State private var copiedItem: String?
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Live JIT Status Card
                    statusCard

                    // Launcher Feedback Banner (if any)
                    if let message = launcher.statusMessage {
                        launcherFeedbackBanner(message)
                    }

                    // Action Buttons (StikDebug, SideStore, TrollStore)
                    actionButtonsSection

                    // Diagnostics / Process Info (PID, Bundle ID, csops)
                    diagnosticsSection

                    // Helpful Setup Guidance
                    setupGuidanceSection

                    // Device & Version Footer
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 720)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Interpres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshStatus) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onReceive(timer) { _ in
                refreshStatus()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    refreshStatus()
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "laptopcomputer.and.ipad")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 4)

            Text("Interpres")
                .font(.title.bold())

            Text("Mac app translation layer for iPadOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: jitEnabled ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(jitEnabled ? Color.green : Color.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(jitEnabled ? "JIT Active" : "JIT Inactive")
                        .font(.title3.bold())
                        .foregroundStyle(jitEnabled ? Color.green : Color.primary)

                    Text(jitEnabled
                         ? "Debugger attached via csops (CS_DEBUGGED). Mac binaries can execute."
                         : "Debugger not attached. Unsigned code execution is blocked by the kernel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Text("Kernel Flag:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rawFlags)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(jitEnabled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Live Polling")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(jitEnabled ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1.5)
        )
    }

    private func launcherFeedbackBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if launcher.isTriggering {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: launcher.isSuccess == true ? "checkmark.circle.fill" : (launcher.isSuccess == false ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                    .foregroundStyle(launcher.isSuccess == true ? Color.green : (launcher.isSuccess == false ? Color.orange : Color.blue))
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: { launcher.clearStatus() }) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-Tap JIT Trigger")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(JITMethod.allCases) { method in
                methodCard(method)
            }
        }
    }

    private func methodCard(_ method: JITMethod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: method.iconName)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(method.title)
                            .font(.body.weight(.semibold))

                        Text(method.scheme)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(method.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    launcher.trigger(method)
                } label: {
                    HStack(spacing: 4) {
                        if launcher.isTriggering && launcher.lastTriggeredMethod == method {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Trigger")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(launcher.isTriggering)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Process & Diagnostics")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                diagnosticRow(
                    label: "Process ID (PID)",
                    value: "\(JITStatus.processID)",
                    copyableText: "\(JITStatus.processID)",
                    id: "pid"
                )
                Divider()
                    .padding(.leading, 16)
                diagnosticRow(
                    label: "Bundle Identifier",
                    value: JITStatus.bundleID,
                    copyableText: JITStatus.bundleID,
                    id: "bundle"
                )
                Divider()
                    .padding(.leading, 16)
                diagnosticRow(
                    label: "csops Status",
                    value: rawFlags,
                    copyableText: rawFlags,
                    id: "flags"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func diagnosticRow(label: String, value: String, copyableText: String, id: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(.primary)

            Button {
                UIPasteboard.general.string = copyableText
                withAnimation {
                    copiedItem = id
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedItem == id {
                        withAnimation {
                            copiedItem = nil
                        }
                    }
                }
            } label: {
                Image(systemName: copiedItem == id ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copiedItem == id ? Color.green : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var setupGuidanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Guidance")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                guidanceItem(
                    title: "Why JIT is Required",
                    text: "iOS prevents apps from allocating writable and executable memory simultaneously unless a debugger is attached. Translating Mac ARM64 binaries requires JIT compilation to load and run native code."
                )

                Divider()

                guidanceItem(
                    title: "StikDebug (On-Device)",
                    text: "1. Install and open StikDebug.\n2. Ensure the local loopback VPN configuration is connected.\n3. Return here and tap 'Trigger' next to StikDebug. It will pass the current PID and Bundle ID via the stikjit:// scheme."
                )

                Divider()

                guidanceItem(
                    title: "SideStore (WireGuard VPN)",
                    text: "1. Connect your device to SideStore's pairing WireGuard VPN.\n2. Tap 'Trigger' next to SideStore. SideStore will attach its debugger via sidestore:// and redirect back."
                )

                Divider()

                guidanceItem(
                    title: "TrollStore (Root Helper)",
                    text: "Devices installed via TrollStore can use root helper privileges. Tap 'Trigger' next to TrollStore to invoke apple-magnifier://."
                )

                Divider()

                guidanceItem(
                    title: "Computer / Xcode Debugger",
                    text: "You can also attach JIT manually by connecting your iPad to a Mac running Xcode (Debug > Attach to Process) or using pymobiledevice3 / jitstreamer over the local network."
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func guidanceItem(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerSection: some View {
        Text(deviceLine)
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }

    private var deviceLine: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Interpres \(version) · \(UIDevice.current.systemName) \(os)"
    }

    private func refreshStatus() {
        jitEnabled = JITStatus.isEnabled
        rawFlags = JITStatus.flagsHexString
    }
}
