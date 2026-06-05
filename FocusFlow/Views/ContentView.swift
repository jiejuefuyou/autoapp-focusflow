import SwiftUI
import UIKit
import AudioToolbox

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n

    @State private var selectedPreset: FocusPreset = .short25
    @State private var customDurationSeconds: TimeInterval = 30 * 60

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showAnalytics = false

    /// Drives the "Nice focus!" celebration overlay that fires when a session
    /// completes. Auto-clears 1.6s after appearing.
    @State private var showCompletionCelebration = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    todaySummary
                    presetSection
                    TimerView(placeholderDuration: plannedDuration)
                    startButton
                    if !store.history.isEmpty {
                        recentSessions
                    }
                }
                .padding(Spacing.md)
            }
            .overlay(alignment: .top) {
                if showCompletionCelebration {
                    celebrationToast
                        .padding(.top, Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
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
            // CRITICAL: modal sheets need own .id(l10n.override) for language
            // switch to take effect; root-level .id on FocusFlowApp doesn't
            // propagate to scene presentation host.
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
            .navigationDestination(isPresented: $showAnalytics) {
                WeeklyAnalyticsView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
            .sheet(item: tagPickerItemBinding) { pending in
                ProjectTagPicker(sessionId: pending.id)
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
                    .onAppear { triggerCompletionFeedback() }
            }
        }
    }

    // MARK: - Sections

    /// Compact "Today" card at the top: session count + total focused time.
    /// Hidden when zero sessions today (avoid empty-state shame).
    @ViewBuilder
    private var todaySummary: some View {
        if todaysSessions.count > 0 {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Today"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(todaysSessions.count) \(String(localized: "sessions today")) · \(todaysTotalFormatted)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)   // 14 = data card horizontal; sits between sm(8)/md(16)
            .padding(.vertical, 12)     // 12 = data card vertical (Radius.md = 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))   // 14 = matches horizontal inset
        }
    }

    private var celebrationToast: some View {
        Label(LocalizedStringKey("Nice focus!"), systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)   // 10 = pill vertical, between xs(4)/sm(8)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 4)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Focus technique"))
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
                    .font(Typography.bodyEmphasis)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, 12)   // 12 = row horizontal, matches Radius.md visual
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))   // 10 = row card, smaller than md(12) for compact list rhythm
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

    /// Sessions started in today's calendar day (any state — completed or
    /// cancelled). Used by `todaySummary` for the "X sessions today" pill.
    private var todaysSessions: [FocusSession] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return store.history.filter { cal.startOfDay(for: $0.startedAt) == today }
    }

    /// Total focused time today, formatted as "1h 35m" or "35m".
    private var todaysTotalFormatted: String {
        let totalSeconds = todaysSessions.reduce(0) {
            $0 + ($1.actualDuration > 0 ? $1.actualDuration : $1.duration)
        }
        let hours = Int(totalSeconds) / 3600
        let mins = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
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
        return "\(m) \(String(localized: "min"))"
    }

    /// Apple's stock "tri-tone" alert + haptic + visible celebration toast.
    ///
    /// Fires once when the tag picker appears (i.e. immediately after a
    /// session completes). The toast is purely cosmetic but matters for
    /// closing the dopamine loop — without it the only signal is the modal
    /// sheet, which feels like a chore rather than a reward.
    private func triggerCompletionFeedback() {
        AudioServicesPlaySystemSound(1025)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            showCompletionCelebration = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                showCompletionCelebration = false
            }
        }
    }
}

/// Wraps a pending session id so `.sheet(item:)` can drive the tag picker.
private struct PendingTagItem: Identifiable, Hashable {
    let id: UUID
}
