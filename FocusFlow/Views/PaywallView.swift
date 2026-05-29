import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    // Computed helper: are we in a failed state?
    private var isFailed: Bool {
        if case .failed = iap.purchaseState { return true }
        return false
    }

    private var failureMessage: String {
        if case .failed(let msg) = iap.purchaseState { return msg }
        return ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)

                    Text(LocalizedStringKey("FocusFlow Pro"))
                        .font(.largeTitle.bold())

                    Text(LocalizedStringKey("One-time purchase. No subscription. Unlock everything forever."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // ── State banners (visible, non-buried) ──
                    stateBanner

                    // ── Feature list — ONLY shipped + actually-gated features ──
                    // 2026-05-26 (v1.0.11) Sprint A P0-1: removed 3 fake promises
                    // ("Full history 7/30/90", "Export CSV", "Focus Filter gate")
                    // that were advertised but never implemented or never gated.
                    // Apple 2.3.1 (Accurate Metadata) reject risk + user 1-star.
                    // All 3 rows below correspond to real gates verified in code:
                    //   * unlimited sessions  -> SessionStore.freeDailySessionLimit
                    //   * custom durations    -> FocusPreset.custom.requiresPremium
                    //   * unlimited tags      -> ProjectTagPicker addTagButton gate
                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity",               LocalizedStringKey("Unlimited daily sessions"))
                        feature("slider.horizontal.3",    LocalizedStringKey("Custom session durations (any length)"))
                        feature("tag.fill",               LocalizedStringKey("Unlimited project tags with emoji + color"))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    purchaseButton
                        .padding(.horizontal)

                    Button(LocalizedStringKey("Restore Purchase")) {
                        Task { await iap.restore() }
                    }
                    .font(.footnote)

                    VStack(spacing: 4) {
                        Label(LocalizedStringKey("No subscription. No data collected. Ever."),
                              systemImage: "lock.shield.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(legalese)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            .onChange(of: iap.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
            .task { await iap.loadProducts() }
            // ── Alert for failure states — always visible, not buried ──
            .alert(
                LocalizedStringKey("Purchase Issue"),
                isPresented: Binding(
                    get: { isFailed },
                    set: { if !$0 { iap.purchaseState = .idle } }
                )
            ) {
                Button(LocalizedStringKey("OK")) {
                    iap.purchaseState = .idle
                }
                Button(LocalizedStringKey("Try Again")) {
                    Task { await iap.purchase() }
                }
            } message: {
                Text(failureMessage)
            }
        }
    }

    // MARK: - State banner (non-failed inline states)

    @ViewBuilder
    private var stateBanner: some View {
        if case .pending = iap.purchaseState {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill").foregroundStyle(.orange)
                Text(LocalizedStringKey("Purchase pending approval"))
                    .font(.caption.weight(.semibold))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        } else if case .unverified = iap.purchaseState {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(LocalizedStringKey("Purchase could not be verified. Tap Restore."))
                    .font(.caption.weight(.semibold))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        } else if case .cancelled = iap.purchaseState {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                Text(LocalizedStringKey("Purchase cancelled."))
                    .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        } else if case .success = iap.purchaseState {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(LocalizedStringKey("Purchase successful! Welcome to Pro."))
                    .font(.caption.weight(.semibold))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    // MARK: - Purchase button

    @ViewBuilder
    private var purchaseButton: some View {
        if iap.isPremium {
            Label(LocalizedStringKey("Pro unlocked"), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.green)
        } else if let product = iap.products.first {
            Button {
                Task { await iap.purchase() }
            } label: {
                HStack {
                    if iap.purchaseInProgress {
                        ProgressView().tint(.white)
                    }
                    Text(iap.purchaseInProgress
                         ? LocalizedStringKey("Processing\u{2026}")
                         : LocalizedStringKey("Unlock for \(product.displayPrice)"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                // PaywallView CTA upgrade — purchase moment "wow" (art-audit P1 2026-05-23)
                .background(LinearGradient.brandHero, in: RoundedRectangle(cornerRadius: Radius.lg))
                .foregroundStyle(.white)
                .brandCardShadow(Elevation.floating)
                .opacity(iap.purchaseInProgress ? 0.5 : 1.0)
            }
            .disabled(iap.purchaseInProgress)
            .accessibilityIdentifier("paywall.cta.unlock")
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    // MARK: - Feature row

    private func feature(_ icon: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            // Circular icon background gives each row a tactile chip + lifts the
            // icon from flat-tint sea (art-audit 2026-05-23 P0-3). 7 feature rows
            // previously rendered as a same-color soup; tinted circle bg adds
            // visual layering without breaking the accent palette.
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(label)
            Spacer()
        }
    }

    // MARK: - Legalese

    private var legalese: String {
        String(localized: "paywall.legalese")
    }
}
