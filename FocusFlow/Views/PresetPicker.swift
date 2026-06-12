import SwiftUI
import UIKit

/// A curated library of named focus techniques rendered as selectable rows,
/// followed by the Custom-duration affordance.
///
/// Each row shows the technique name, a one-line description, and its
/// focus/break rhythm. Premium techniques (and Custom) show a lock glyph for
/// free users; tapping a locked row opens the paywall instead of selecting it.
/// Tapping a free/unlocked row selects the preset exactly as before — the
/// parent's `plannedDuration` then derives the timer length from
/// `FocusPreset.seconds`, so timer behavior is unchanged.
struct PresetPicker: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n

    @Binding var selection: FocusPreset
    /// Custom duration in seconds; only meaningful when `selection == .custom`.
    /// Premium users edit this through the sheet.
    @Binding var customDurationSeconds: TimeInterval

    /// Called when the user taps a locked premium preset (or Custom) while
    /// *not* entitled and the one-time premium trial is already spent, so the
    /// parent can present `PaywallView`.
    var onPremiumGated: () -> Void = {}

    /// Called when a free user taps a locked premium technique while the
    /// one-time free trial is still available, so the parent can present the
    /// trial-offer sheet for that technique.
    var onTrialOffer: (FocusPreset) -> Void = { _ in }

    /// Disable interaction while a session is running.
    var disabled: Bool = false

    @State private var showCustomSheet = false

    /// True while the free user still has their one-time premium-technique trial.
    private var trialAvailable: Bool {
        store.premiumTrialAvailable(isPremium: iap.isPremium)
    }

    var body: some View {
        VStack(spacing: 8) {   // 8 = sm rhythm between technique rows
            ForEach(FocusPreset.library) { preset in
                presetRow(for: preset)
            }
            customRow
        }
        .opacity(disabled ? 0.45 : 1.0)
        .allowsHitTesting(!disabled)
        .sheet(isPresented: $showCustomSheet) {
            CustomDurationSheet(
                durationSeconds: $customDurationSeconds,
                onConfirm: {
                    selection = .custom
                    showCustomSheet = false
                }
            )
            .environment(l10n)
            .environment(\.locale, l10n.currentLocale)
            .id(l10n.override)
        }
    }

    // MARK: - Technique row

    /// Renders one curated-technique row: name + description + focus/break
    /// rhythm. Locked premium rows show a lock glyph and route to the paywall.
    @ViewBuilder
    private func presetRow(for preset: FocusPreset) -> some View {
        let isSelected = (selection == preset)
        let isPremiumGated = preset.requiresPremium && !iap.isPremium
        // A premium row that the free user can still *taste* once: shown as an
        // invitation ("Try free"), not a wall. After the trial is spent it
        // becomes a normal locked row that routes to the paywall.
        let isTrialOffer = isPremiumGated && trialAvailable
        let isLocked = isPremiumGated && !trialAvailable

        Button {
            if isTrialOffer {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTrialOffer(preset)
            } else if isLocked {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPremiumGated()
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
                selection = preset
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon(for: preset, isSelected: isSelected, isLocked: isLocked))
                    .font(.body.weight(.semibold))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(preset.nameKey))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(LocalizedStringKey(preset.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isTrialOffer {
                    tryFreePill
                        .layoutPriority(1)
                }

                Text(rhythmLabel(for: preset))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .secondary)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel(for: preset, isLocked: isLocked, isTrialOffer: isTrialOffer))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Small "Try free" capsule shown on premium technique rows while the user's
    /// one-time trial is still available — turns the lock into an invitation.
    private var tryFreePill: some View {
        Text(LocalizedStringKey("Try free"))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    /// SF Symbol per row: a selection checkmark when chosen, a lock when gated,
    /// otherwise an intensity cue keyed to the focus length
    /// (bolt = sprint, flame = standard, mountain = deep).
    private func icon(for preset: FocusPreset, isSelected: Bool, isLocked: Bool) -> String {
        if isLocked { return "lock.fill" }
        if isSelected { return "checkmark.circle.fill" }
        switch preset.focusMinutes {
        case ..<30:  return "bolt.fill"
        case ..<60:  return "flame.fill"
        default:     return "mountain.2.fill"
        }
    }

    /// "52 / 17" focus-break rhythm. Locale-neutral digits; the unit is implied
    /// by the description sentence, so no localized "min" suffix is needed here.
    private func rhythmLabel(for preset: FocusPreset) -> String {
        "\(preset.focusMinutes) / \(preset.breakMinutes)"
    }

    private func accessibilityLabel(for preset: FocusPreset, isLocked: Bool, isTrialOffer: Bool) -> Text {
        let name = Text(LocalizedStringKey(preset.nameKey))
        if isTrialOffer {
            return name + Text(", ") + Text(LocalizedStringKey("Premium technique. Free to try once."))
        }
        if isLocked {
            return name + Text(", ") + Text(LocalizedStringKey("Premium"))
        }
        return name
    }

    // MARK: - Custom-duration row

    @ViewBuilder
    private var customRow: some View {
        let isSelected = (selection == .custom)
        let isLocked = !iap.isPremium

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if iap.isPremium {
                showCustomSheet = true
            } else {
                onPremiumGated()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "slider.horizontal.3"))
                    .font(.body.weight(.semibold))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    customTitleView
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(LocalizedStringKey("preset.custom.desc"))
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey("Custom Duration")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var customTitleView: some View {
        if selection == .custom && customDurationSeconds > 0 {
            let mins = Int(customDurationSeconds / 60)
            // Foundation's Measurement formatter handles locale-correct unit
            // pluralization + abbreviation without us juggling LocalizedStringKey
            // interpolation tables.
            Text(Self.formatMinutes(mins))
        } else {
            Text(LocalizedStringKey("Custom"))
        }
    }

    private static func formatMinutes(_ mins: Int) -> String {
        let measurement = Measurement(value: Double(mins), unit: UnitDuration.minutes)
        let formatter = MeasurementFormatter()
        // Pin to the in-app override locale: MeasurementFormatter defaults to
        // the SYSTEM locale, which would leak system-language unit names
        // ("分" vs "min") after an in-app language switch (lesson #63 sibling).
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: measurement)
    }
}

// MARK: - Custom duration sheet (Premium)

private struct CustomDurationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var durationSeconds: TimeInterval
    var onConfirm: () -> Void

    @State private var minutes: Int = 30

    /// Allowed range per spec — 5 min minimum, 240 (4 h) maximum.
    private let minMinutes = 5
    private let maxMinutes = 240

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Text(LocalizedStringKey("Custom Duration"))
                    .font(.title2.bold())
                    .padding(.top, Spacing.lg)

                // 80pt mono display — geometry-bound to sheet center; not Dynamic Type
                Text("\(minutes)")
                    .font(.system(size: 80, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.tint)

                Text(LocalizedStringKey("minutes"))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Stepper(value: $minutes, in: minMinutes...maxMinutes, step: 5) {
                    Text(LocalizedStringKey("Adjust duration"))
                        .font(.subheadline)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()

                Button {
                    durationSeconds = TimeInterval(minutes * 60)
                    onConfirm()
                } label: {
                    Text(LocalizedStringKey("Save"))
                        .font(Typography.bodyEmphasis)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, Spacing.lg)
            }
            .navigationTitle(Text(LocalizedStringKey("Custom Duration")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .onAppear {
                let current = Int(durationSeconds / 60)
                if current >= minMinutes && current <= maxMinutes {
                    minutes = current
                }
            }
        }
    }
}
