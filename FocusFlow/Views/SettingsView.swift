import SwiftUI

struct SettingsView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("Premium")) {
                    if iap.isPremium {
                        Label(LocalizedStringKey("Pro unlocked"), systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Text(LocalizedStringKey("Free tier"))
                            Spacer()
                            Text("\(store.sessionsToday()) / \(SessionStore.freeDailySessionLimit) sessions today")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button { showPaywall = true } label: {
                            Label(LocalizedStringKey("Unlock Pro"), systemImage: "sparkles")
                        }
                    }
                    Button(LocalizedStringKey("Restore Purchases")) { Task { await iap.restore() } }
                }

                Section(LocalizedStringKey("Language")) {
                    LanguagePicker()
                }

                Section(LocalizedStringKey("Total stats")) {
                    LabeledContent(LocalizedStringKey("Total sessions"), value: "\(store.history.count)")
                    LabeledContent(LocalizedStringKey("Total time"), value: totalTimeFormatted)
                }

                Section(LocalizedStringKey("About")) {
                    LabeledContent(LocalizedStringKey("Version"), value: appVersion)
                    LabeledContent(LocalizedStringKey("Build"),   value: buildNumber)
                    Link(LocalizedStringKey("Privacy Policy"), destination: URL(string: "https://github.com/jiejuefuyou/autoapp-focusflow/blob/main/PRIVACY.md")!)
                    Link(LocalizedStringKey("Terms of Use"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Label(LocalizedStringKey("No data collected. Ever."), systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("Settings")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(LocalizedStringKey("Done")) { dismiss() } }
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

private struct LanguagePicker: View {
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Picker(LocalizedStringKey("Language"), selection: Binding(
            get: { l10n.override },
            set: { l10n.setOverride($0) }
        )) {
            Text(LocalizedStringKey("System default")).tag("")
            ForEach(LocalizationManager.supportedLanguages, id: \.self) { code in
                Text(LocalizationManager.displayName(for: code)).tag(code)
            }
        }
        .pickerStyle(.menu)
    }
}
