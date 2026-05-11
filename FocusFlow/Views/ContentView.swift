import SwiftUI
import UIKit
import AudioToolbox

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store

    @State private var selectedPreset: FocusPreset = .short25
    @State private var customDurationSeconds: TimeInterval = 30 * 60

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showAnalytics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    presetSection
                    TimerView(placeholderDuration: plannedDuration)
                    startButton
                    if !store.history.isEmpty {
                        recentSessions
                    }
                }
                .padding()
            }
            .navigationTitle(Text(LocalizedStringKey("FocusFlow")))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Settings")))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAnalytics = true } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Analytics")))

                    if !iap.isPremium {
                        Button { showPaywall = true } label: {
                            Label(LocalizedStringKey("Pro"), systemImage: "sparkles")
                                .font(.caption.bold())
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .navigationDestination(isPresented: $showAnalytics) {
                WeeklyAnalyticsView()
            }
            .sheet(item: tagPickerItemBinding) { pending in
                ProjectTagPicker(sessionId: pending.id)
                    .onAppear { triggerCompletionFeedback() }
            }
        }
    }

    // MARK: - Sections

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Duration"))
                .font(.headline)
            PresetPicker(
                selection: $selectedPreset,
                customDurationSeconds: $customDurationSeconds,
                onPremiumGated: { showPaywall = true },
                disabled: store.currentSession != nil
            )

            if !iap.isPremium {
                Text("\(store.sessionsToday()) / \(SessionStore.freeDailySessionLimit) \(String(localized: "sessions today"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var startButton: some View {
        if store.currentSession == nil {
            Button {
                handleStart()
            } label: {
                Label(LocalizedStringKey("Start"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("Recent Sessions"))
                .font(.headline)

            ForEach(recentSlice) { session in
                HStack(spacing: 12) {
                    Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(session.completed ? .green : .secondary)

                    if let id = session.tagId, let tag = store.tag(forId: id) {
                        Text(tag.emoji)
                        Text(tag.displayName)
                            .lineLimit(1)
                    } else {
                        Text(LocalizedStringKey("No tag"))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(durationLabel(seconds: session.actualDuration > 0 ? session.actualDuration : session.duration))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers

    private var plannedDuration: TimeInterval {
        switch selectedPreset {
        case .custom: return customDurationSeconds
        default:      return selectedPreset.seconds
        }
    }

    private var canStart: Bool {
        plannedDuration > 0
    }

    private var recentSlice: [FocusSession] {
        Array(store.history.suffix(5).reversed())
    }

    private var tagPickerItemBinding: Binding<PendingTagItem?> {
        Binding(
            get: {
                store.pendingTagAssignmentSessionId.map(PendingTagItem.init)
            },
            set: { newValue in
                if newValue == nil {
                    store.dismissPendingTag()
                }
            }
        )
    }

    private func handleStart() {
        // Free tier daily limit check.
        if !iap.isPremium && store.sessionsToday() >= SessionStore.freeDailySessionLimit {
            showPaywall = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.startSession(duration: plannedDuration)
    }

    private func durationLabel(seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        return "\(m) min"
    }

    /// Apple's stock "tri-tone" alert + haptic.
    private func triggerCompletionFeedback() {
        AudioServicesPlaySystemSound(1025)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Wraps a pending session id so `.sheet(item:)` can drive the tag picker.
private struct PendingTagItem: Identifiable, Hashable {
    let id: UUID
}
