import SwiftUI
import UIKit

/// Horizontal row of three preset chips (25 / 50 / 90) plus a Custom chip.
/// Custom is Premium-gated — taps from free users open the paywall instead of
/// the custom-duration sheet.
struct PresetPicker: View {
    @Environment(IAPManager.self) private var iap

    @Binding var selection: FocusPreset
    /// Custom duration in seconds; only meaningful when `selection == .custom`.
    /// Premium users edit this through the sheet.
    @Binding var customDurationSeconds: TimeInterval

    /// Called when the user taps Custom while *not* entitled, so the parent
    /// can present `PaywallView`.
    var onPremiumGated: () -> Void = {}

    /// Disable interaction while a session is running.
    var disabled: Bool = false

    @State private var showCustomSheet = false

    var body: some View {
        HStack(spacing: 10) {
            chip(for: .short25, label: LocalizedStringKey("25 min"))
            chip(for: .medium50, label: LocalizedStringKey("50 min"))
            chip(for: .long90, label: LocalizedStringKey("90 min"))
            customChip
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
        }
    }

    @ViewBuilder
    private func chip(for preset: FocusPreset, label: LocalizedStringKey) -> some View {
        let isSelected = (selection == preset)
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = preset
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var customChip: some View {
        let isSelected = (selection == .custom)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if iap.isPremium {
                showCustomSheet = true
            } else {
                onPremiumGated()
            }
        } label: {
            HStack(spacing: 4) {
                if !iap.isPremium {
                    Image(systemName: "lock.fill").font(.caption2)
                }
                customLabelView
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey("Custom Duration")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var customLabelView: some View {
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
            VStack(spacing: 32) {
                Text(LocalizedStringKey("Custom Duration"))
                    .font(.title2.bold())
                    .padding(.top, 24)

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
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    durationSeconds = TimeInterval(minutes * 60)
                    onConfirm()
                } label: {
                    Text(LocalizedStringKey("Save"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 24)
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
