import SwiftUI
import UIKit

/// Big circle countdown with start / pause / resume / stop affordances.
///
/// Presents itself in two states:
/// 1. **Idle** — no active session. Shows the chosen preset duration grayed
///    out and an inert ring so the user has a visual anchor.
/// 2. **Active** — counts down, animating the ring stroke from full → empty.
///
/// The whole card is tap-friendly: tapping the ring toggles play/pause when a
/// session is active (the explicit buttons stay for accessibility). On
/// completion the parent observes `store.pendingTagAssignmentSessionId` and
/// presents the ProjectTagPicker.
struct TimerView: View {
    @Environment(SessionStore.self) private var store

    /// Preview / placeholder duration to render when no session is active.
    /// ContentView passes the user's last-selected preset here.
    let placeholderDuration: TimeInterval

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ring
            controls
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            // Background track.
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 14)

            // Segment markers — 5-min tick around the ring (one tick per 5 min
            // of the *planned* duration, capped at 18 ticks to avoid clutter).
            // Lightweight visual cue that timer is segmented, not a single blob.
            ForEach(segmentTickAngles, id: \.self) { angle in
                Rectangle()
                    .fill(Color.secondary.opacity(0.30))
                    .frame(width: 2, height: 8)
                    .offset(y: -130 + 7)
                    .rotationEffect(.degrees(angle))
            }

            // Progress arc — tinted by phase so FOCUS vs BREAK is legible at a
            // glance even without reading the label (focus = brand accent,
            // break = a calmer teal).
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    phaseColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 6) {
                Text(formattedRemaining)
                    // 56pt fixed = ring center display, geometry-bound to 260×260 ring frame; monospacedDigit() preserves digit-width stability so countdown doesn't jitter
                    .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityLabel(formattedRemainingAccessibility)

                if store.currentSession != nil {
                    // FOCUS / BREAK phase chip — color-coded label that also
                    // reflects the paused state. The most important running-state
                    // cue (which leg of the cycle am I in?).
                    Text(phaseStatusKey)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.isRunning ? phaseColor : .secondary)
                        .textCase(.uppercase)

                    if let cyclesKey = cyclesRemainingKey {
                        Text(cyclesKey)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityLabel(cyclesAccessibilityLabel ?? Text(""))
                    }
                } else {
                    // Idle state — without an entry hint, the ring looks tappable
                    // but its onTapGesture is guarded (line 81) and noops. Users
                    // tap the ring and nothing happens, breaking the model. Show
                    // an explicit affordance pointing at the Start button below
                    // (art-audit 2026-05-23 P0-2).
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey("Ready to focus"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(width: 260, height: 260)
        .contentShape(Circle())
        .onTapGesture {
            guard store.currentSession != nil else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if store.isRunning {
                store.pause()
            } else {
                store.resume()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if store.currentSession == nil {
            // Idle — no controls; PresetPicker above is the entry point.
            EmptyView()
        } else {
            HStack(spacing: 20) {
                stopButton
                playPauseButton
            }
        }
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.cancel()
        } label: {
            Label(LocalizedStringKey("Stop"), systemImage: "stop.fill")
                .font(Typography.bodyEmphasis)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .accessibilityLabel(Text(LocalizedStringKey("Stop")))
    }

    private var playPauseButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if store.isRunning {
                store.pause()
            } else {
                store.resume()
            }
        } label: {
            Label(
                LocalizedStringKey(store.isRunning ? "Pause" : "Resume"),
                systemImage: store.isRunning ? "pause.fill" : "play.fill"
            )
            .font(Typography.bodyEmphasis)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(Text(LocalizedStringKey(store.isRunning ? "Pause" : "Resume")))
    }

    // MARK: - Phase presentation

    /// Ring + label color for the active phase. Break uses a calm teal that's
    /// clearly distinct from the brand accent so the user reads "rest, not work"
    /// without parsing text. Idle/focus stay on the accent.
    private var phaseColor: Color {
        switch store.currentPhase {
        case .focus: return .accentColor
        case .break: return .teal
        }
    }

    /// The FOCUS/BREAK status chip key, accounting for the paused state. When
    /// paused we keep showing the phase so the user knows what they'll resume
    /// into, but the color drops to secondary (handled at the call site).
    private var phaseStatusKey: LocalizedStringKey {
        switch store.currentPhase {
        case .break:
            return LocalizedStringKey(store.isRunning ? "Break" : "Break paused")
        case .focus:
            return LocalizedStringKey(store.isRunning ? "Focusing" : "Paused")
        }
    }

    /// Secondary line under the phase chip describing the auto-cycle plan:
    /// "Looping" for an open-ended run, "%lld more blocks" while focus blocks
    /// remain queued. `nil` (hidden) for a plain single focus+break or the last
    /// block of a run — no clutter when there's nothing more to chain.
    private var cyclesRemainingKey: LocalizedStringKey? {
        let remaining = store.cyclesRemaining
        guard remaining > 0 else { return nil }
        if remaining == Int.max {
            return LocalizedStringKey("Looping")
        }
        return LocalizedStringKey("\(remaining) more blocks")
    }

    /// VoiceOver phrasing for the cycle line (the visible "%lld more blocks"
    /// reads awkwardly to a screen reader, so we spell it out).
    private var cyclesAccessibilityLabel: Text? {
        let remaining = store.cyclesRemaining
        guard remaining > 0 else { return nil }
        if remaining == Int.max {
            return Text(LocalizedStringKey("Looping until you stop"))
        }
        return Text(String(format: NSLocalizedString("cycles.remaining.value",
                                                     comment: "N focus blocks remaining in the auto-cycle run"),
                           remaining))
    }

    // MARK: - Derived

    /// Angles (degrees, 0 = top) for the 5-min segment ticks around the ring.
    /// Uses the active session's planned duration; falls back to the
    /// placeholder when idle. Capped at 18 ticks (90 min / 5 min) to keep the
    /// ring legible.
    private var segmentTickAngles: [Double] {
        let totalSeconds = store.currentSession?.duration ?? placeholderDuration
        guard totalSeconds >= 5 * 60 else { return [] }
        let segmentCount = min(Int(totalSeconds / (5 * 60)), 18)
        guard segmentCount > 1 else { return [] }
        let step = 360.0 / Double(segmentCount)
        return (0..<segmentCount).map { Double($0) * step }
    }

    /// Stroke progress 0…1. Ring is *full* at start and drains as time elapses.
    private var progress: CGFloat {
        guard let session = store.currentSession, session.duration > 0 else {
            return 0
        }
        let remaining = max(0, store.timeRemaining)
        return CGFloat(remaining / session.duration)
    }

    private var formattedRemaining: String {
        let seconds: TimeInterval
        if store.currentSession != nil {
            seconds = max(0, store.timeRemaining)
        } else {
            seconds = max(0, placeholderDuration)
        }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var formattedRemainingAccessibility: String {
        let total = store.currentSession != nil ? max(0, store.timeRemaining) : placeholderDuration
        let mins = Int(total) / 60
        let secs = Int(total) % 60
        return "\(mins) minutes \(secs) seconds remaining"
    }
}
