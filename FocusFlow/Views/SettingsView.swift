import SwiftUI

struct SettingsView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n
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
                            Text("\(store.sessionsToday()) / \(SessionStore.freeDailySessionLimit) \(String(localized: "sessions today"))")
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

                Section {
                    Stepper(
                        value: Binding(
                            get: { store.dailyGoalMinutes },
                            set: { store.dailyGoalMinutes = $0 }
                        ),
                        in: SessionStore.dailyGoalRange,
                        step: 15
                    ) {
                        HStack {
                            Text(LocalizedStringKey("Daily focus goal"))
                            Spacer()
                            Text(goalValueFormatted)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("Daily goal"))
                } footer: {
                    Text(LocalizedStringKey("Your target focus time each day. Track it on the home screen ring."))
                }

                Section(LocalizedStringKey("Focus Filter (iOS 17+)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(.tint)
                            Text(LocalizedStringKey("Focus Filter"))
                                .font(.headline)
                        }
                        Text(LocalizedStringKey("Auto-start a Pomodoro session when you turn on a Focus mode in iOS Settings. Customize the session length and project tag per Focus."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link(destination: URL(string: "App-prefs:Focus")!) {
                            HStack {
                                Text(LocalizedStringKey("Configure in iOS Settings"))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .padding(.vertical, 4)
                }

                Section(LocalizedStringKey("Total stats")) {
                    LabeledContent(LocalizedStringKey("Total sessions"), value: "\(store.history.count)")
                    LabeledContent(LocalizedStringKey("Total time"), value: totalTimeFormatted)
                }

                CrossPromoSection(currentAppStoreID: "6770252811")

                Section(LocalizedStringKey("About")) {
                    LabeledContent(LocalizedStringKey("Version"), value: appVersion)
                    LabeledContent(LocalizedStringKey("Build"),   value: buildNumber)
                    Link(LocalizedStringKey("Support"), destination: URL(string: "https://jiejuefuyou.github.io/support-focusflow")!)
                    Link(LocalizedStringKey("Privacy Policy"), destination: URL(string: "https://jiejuefuyou.github.io/privacy.html")!)
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
            // Per-modal env injection (lesson #34).
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
        }
    }

    private var totalTimeFormatted: String {
        let totalSeconds = store.history.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    /// "%lld min" with the goal value substituted (e.g. "90 min").
    private var goalValueFormatted: String {
        String(format: NSLocalizedString("minutes.count", comment: "minutes count"),
               store.dailyGoalMinutes)
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
