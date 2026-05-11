import SwiftUI

struct SettingsView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Premium") {
                    if iap.isPremium {
                        Label("Pro unlocked", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Text("Free tier")
                            Spacer()
                            Text("\(store.sessionsToday()) / \(SessionStore.freeDailySessionLimit) sessions today")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button { showPaywall = true } label: {
                            Label("Unlock Pro", systemImage: "sparkles")
                        }
                    }
                    Button("Restore Purchase") { Task { await iap.restore() } }
                }

                Section("Total stats") {
                    LabeledContent("Total sessions", value: "\(store.history.count)")
                    LabeledContent("Total time", value: totalTimeFormatted)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/jiejuefuyou/autoapp-focusflow/blob/main/PRIVACY.md")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Label("No data collected. Ever.", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var totalTimeFormatted: String {
        let totalSeconds = store.history.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
