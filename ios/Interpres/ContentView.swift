import SwiftUI

struct ContentView: View {
    @State private var jitEnabled = JITStatus.isEnabled
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Text("Interpres")
                .font(.largeTitle.bold())
            Text("Mac app translation layer")
                .foregroundStyle(.secondary)

            Label(
                jitEnabled ? "JIT is on" : "JIT is off",
                systemImage: jitEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.title2)
            .foregroundStyle(jitEnabled ? .green : .red)
            .padding(.top, 24)

            if !jitEnabled {
                Text("Attach with StikDebug or SideStore to turn it on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(deviceLine)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        }
        .padding()
        .onReceive(timer) { _ in
            jitEnabled = JITStatus.isEnabled
        }
    }

    private var deviceLine: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Interpres \(version) · \(UIDevice.current.systemName) \(os)"
    }
}
