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

    /// The premium technique whose one-time free-trial offer sheet is showing.
    /// Non-nil drives the `TrialOfferSheet`; cleared on dismiss.
    @State private var trialOfferPreset: FocusPreset?

    /// Set when the user taps "Unlock" inside the trial sheet; the paywall is
    /// then presented from the trial sheet's `onDismiss` so the sheets don't
    /// swap mid-transition.
    @State private var pendingPaywallAfterTrial = false

    /// Drives the "Nice focus!" celebration overlay that fires when a session
    /// completes. Auto-clears 1.6s after appearing.
    @State private var showCompletionCelebration = false

    /// Drives the contextual "you've hit the free daily limit" upsell alert. A
    /// free user who taps Start after 5 sessions sees this tasteful prompt (with
    /// the reason) instead of a silent stop or a cold full-screen paywall; tapping
    /// "Unlock unlimited" then opens the paywall. (Round-6 greenlit contextual
    /// upsell at the 5-sessions/day wall.)
    @State private var showDailyLimitUpsell = false

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
            // One-time free-trial offer for a premium technique. `onDismiss`
            // opens the paywall only when the user chose "Unlock", so the two
            // sheets never swap mid-transition (which would silently drop the
            // paywall presentation — AutoChoice PresetGalleryView lesson).
            .sheet(item: $trialOfferPreset, onDismiss: {
                if pendingPaywallAfterTrial {
                    pendingPaywallAfterTrial = false
                    showPaywall = true
                }
            }) { preset in
                TrialOfferSheet(
                    preset: preset,
                    onStartFreeSession: { startTrialSession(preset) },
                    onUnlock: {
                        pendingPaywallAfterTrial = true
                        trialOfferPreset = nil
                    }
                )
                .environment(iap)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .id(l10n.override)
            }
            // Contextual upsell at the free daily-session wall (round-6 greenlit).
            // Explains the limit at the moment of intent and offers the unlock,
            // rather than silently refusing the start or jumping cold to the paywall.
            .alert(
                LocalizedStringKey("You've hit today's free sessions"),
                isPresented: $showDailyLimitUpsell
            ) {
                Button(LocalizedStringKey("Unlock unlimited")) { showPaywall = true }
                Button(LocalizedStringKey("Not now"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Free includes \(SessionStore.freeDailySessionLimit) focus sessions a day. Unlock FocusFlow Pro for unlimited sessions — one payment, no subscription."))
            }
        }
    }

    // MARK: - Sections

    /// Compact "Today" card at the top: session count + total focused time,
    /// plus two retention hooks — a daily focus-minutes goal ring (trailing)
    /// and a "🔥 N-day streak" badge (shown once the streak reaches 2 so a
    /// single day doesn't claim a "streak"). Hidden when zero sessions today
    /// (avoid empty-state shame).
    @ViewBuilder
    private var todaySummary: some View {
        if todaysSessions.count > 0 {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Today"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(todaysSessions.count) \(String(localized: "sessions today")) · \(todaysTotalFormatted)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if store.currentStreak >= 2 {
                        Text("🔥 \(streakLabel(store.currentStreak))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                            .accessibilityLabel(Text(streakLabel(store.currentStreak)))
                    }
                }
                Spacer()

                goalRing
            }
            .padding(.horizontal, 14)   // 14 = data card horizontal; sits between sm(8)/md(16)
            .padding(.vertical, 12)     // 12 = data card vertical (Radius.md = 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))   // 14 = matches horizontal inset
        }
    }

    /// Daily focus-minutes goal ring: today's minutes vs `dailyGoalMinutes`.
    /// Fills as the user focuses; shows a check seal once the goal is met.
    private var goalRing: some View {
        let progress = store.todayGoalProgress()
        let met = store.isTodayGoalMet()
        return ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.02, progress))   // 0.02 floor so a sliver always shows
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            if met {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey("Daily goal")))
        .accessibilityValue(Text(goalAccessibilityValue))
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
                onTrialOffer: { trialOfferPreset = $0 },
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
        startSession(duration: plannedDuration)
    }

    /// Accept the one-time premium-technique trial: select the technique, burn
    /// the trial (persisted, irrevocable), dismiss the offer sheet, then start.
    /// The free daily-session cap still applies — if it's hit we route to the
    /// paywall and leave the trial *unspent* (so it can't be wasted on a blocked
    /// start), exactly mirroring AutoChoice's "burn only on successful grant".
    private func startTrialSession(_ preset: FocusPreset) {
        if !iap.isPremium && store.sessionsToday() >= SessionStore.freeDailySessionLimit {
            pendingPaywallAfterTrial = true
            trialOfferPreset = nil
            return
        }
        selectedPreset = preset
        store.consumePremiumTechniqueTrial()
        trialOfferPreset = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Honor the auto-break toggle for the trial too: a free trial user is
        // clamped to a single focus+break (clampedAutoCycleCount), so they get
        // to *feel* the auto-break rhythm without unlocking multi-cycle.
        let breakSeconds = TimeInterval(preset.breakMinutes * 60)
        if store.autoStartBreaks && breakSeconds > 0 {
            store.startSessionWithAutoBreak(
                focusSeconds: preset.seconds,
                breakSeconds: breakSeconds,
                cycleCount: store.clampedAutoCycleCount(isPremium: iap.isPremium)
            )
        } else {
            store.startSession(duration: preset.seconds)
        }
    }

    /// Single start funnel: enforces the free daily-session cap, then starts a
    /// session of the given duration. Premium gating of the *technique* happens
    /// upstream in the picker (locked rows never reach here for free users
    /// except via the consumed trial path).
    ///
    /// When "Auto-start breaks" is on and the chosen technique prescribes a
    /// break, the session is armed with the auto-break plan so the break runs
    /// automatically on completion (and loops per the clamped cycle count).
    /// A custom duration has no prescribed break, so it always runs as a plain
    /// single focus block regardless of the toggle.
    private func startSession(duration: TimeInterval) {
        if !iap.isPremium && store.sessionsToday() >= SessionStore.freeDailySessionLimit {
            showDailyLimitUpsell = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let breakSeconds = autoBreakSeconds(for: duration)
        if store.autoStartBreaks && breakSeconds > 0 {
            store.startSessionWithAutoBreak(
                focusSeconds: duration,
                breakSeconds: breakSeconds,
                cycleCount: store.clampedAutoCycleCount(isPremium: iap.isPremium)
            )
        } else {
            store.startSession(duration: duration)
        }
    }

    /// Break length (seconds) prescribed by the *currently selected* technique,
    /// or `0` for `.custom` (no prescribed break) / a duration that doesn't map
    /// to the selected preset. Reads `selectedPreset` rather than re-deriving
    /// from `duration` so two presets that happen to share a focus length keep
    /// their distinct break lengths.
    private func autoBreakSeconds(for duration: TimeInterval) -> TimeInterval {
        guard selectedPreset != .custom,
              abs(selectedPreset.seconds - duration) < 0.5 else { return 0 }
        return TimeInterval(selectedPreset.breakMinutes * 60)
    }

    private func durationLabel(seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        return "\(m) \(String(localized: "min"))"
    }

    /// "%lld-day streak" localized with the count substituted. Uses
    /// `String(localized:defaultValue:)`-style interpolation via the format
    /// string so plural-aware locales can adapt.
    private func streakLabel(_ days: Int) -> String {
        String(format: NSLocalizedString("streak.days", comment: "N-day focus streak"), days)
    }

    /// VoiceOver value for the goal ring, e.g. "45 of 90 min".
    private var goalAccessibilityValue: String {
        String(format: NSLocalizedString("goal.progress.value", comment: "today minutes of goal"),
               store.todayFocusMinutes(), store.dailyGoalMinutes)
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
        // Genuine success moment: the user just completed a focus session (this
        // runs as the post-completion tag picker appears). ReviewService
        // self-throttles (≥5 actions, ≥3 days in, ≥122 days between asks) so this
        // never nags — Apple's native prompt surfaces only for an established,
        // satisfied user, which is what eventually accrues honest ratings. NOT on
        // the paywall, NOT on every completion.
        ReviewService.recordSuccess()
        ReviewService.maybeRequestReview()
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
