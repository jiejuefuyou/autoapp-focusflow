import SwiftUI

/// One-time free-trial offer for a Premium focus technique.
///
/// Shown the first (and only) time a free user taps a locked premium technique
/// while their trial is still available. Letting the user *feel* a premium
/// technique once is the strongest desire-builder — so the sheet frames the
/// single free session as a gift, names the technique they're about to run, and
/// offers two paths: start the free session now, or unlock everything.
///
/// The trial is burned by the parent (`onStartFreeSession`) only when the user
/// confirms here, so merely opening this sheet never spends it.
struct TrialOfferSheet: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    /// The premium technique the offer is for (drives the name/description/rhythm).
    let preset: FocusPreset

    /// Accept the free trial: select + start this technique. The parent persists
    /// the one-time flag and starts the session.
    var onStartFreeSession: () -> Void

    /// Skip the trial and go straight to the paywall.
    var onUnlock: () -> Void

    /// Number of premium techniques unlocked by purchasing — computed (never
    /// hardcoded) so the copy stays correct as the catalog grows.
    private var premiumTechniqueCount: Int {
        FocusPreset.premiumLibrary.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, Spacing.xl)

                    Text(LocalizedStringKey("Your free premium technique"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Named technique card — what they're about to taste.
                    techniqueCard

                    Text(LocalizedStringKey("Run it once, on the house. No card, no sign-up."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    startButton
                        .padding(.horizontal)

                    Button(action: onUnlock) {
                        Text(unlockButtonTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, Spacing.lg)
                    .accessibilityIdentifier("trial.cta.unlock")
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text(LocalizedStringKey("Try Premium free")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Technique card

    private var techniqueCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                Text(LocalizedStringKey(preset.nameKey))
                    .font(.headline)
                Spacer()
                Text(rhythmLabel)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(LocalizedStringKey(preset.descriptionKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.lg))
        .padding(.horizontal)
    }

    // MARK: - Buttons

    private var startButton: some View {
        Button(action: onStartFreeSession) {
            Label(LocalizedStringKey("Start free session"), systemImage: "play.fill")
                .font(Typography.bodyEmphasis)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.vertical, 2)
                .background(LinearGradient.brandHero, in: RoundedRectangle(cornerRadius: Radius.lg))
                .foregroundStyle(.white)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("trial.cta.start")
    }

    // MARK: - Helpers

    /// "52 / 17" focus-break rhythm — locale-neutral digits.
    private var rhythmLabel: String {
        "\(preset.focusMinutes) / \(preset.breakMinutes)"
    }

    /// "Unlock all 7 techniques — \(price)" when the price is known, falling
    /// back to a price-free string while StoreKit is still loading the product.
    private var unlockButtonTitle: LocalizedStringKey {
        if let price = iap.products.first?.displayPrice {
            return LocalizedStringKey("Unlock all \(premiumTechniqueCount) techniques — \(price)")
        }
        return LocalizedStringKey("Unlock all Premium")
    }
}
