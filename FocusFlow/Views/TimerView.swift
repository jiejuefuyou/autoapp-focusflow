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
        VStack(spacing: 24) {
            ring
            controls
        }
        .padding(.vertical, 16)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            // Background track.
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 14)

            // Progress arc.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 6) {
                Text(formattedRemaining)
                    .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityLabel(formattedRemainingAccessibility)

                if store.currentSession != nil {
                    Text(LocalizedStringKey(store.isRunning ? "Focusing" : "Paused"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                } else {
                    Text(LocalizedStringKey("Ready to focus"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
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
                .font(.headline)
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
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(Text(LocalizedStringKey(store.isRunning ? "Pause" : "Resume")))
    }

    // MARK: - Derived

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
