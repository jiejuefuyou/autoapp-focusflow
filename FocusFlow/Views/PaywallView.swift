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

                    // ── Honest price-anchor (Pattern D) ──
                    // Generic, undated, no fabricated counts (lessons #44/#53).
                    // The buying emotion in the focus-timer category is
                    // subscription fatigue; framing "pay once vs the field" turns
                    // the price from a cost into the obvious value pick — at zero
                    // gating cost and with nothing to verify/age.
                    priceAnchor

                    // ── State banners (visible, non-buried) ──
                    stateBanner

                    // ── Feature list — ONLY shipped + actually-gated features ──
                    // 2026-05-26 (v1.0.11) Sprint A P0-1: removed 3 fake promises
                    // ("Full history 7/30/90", "Export CSV", "Focus Filter gate")
                    // that were advertised but never implemented or never gated.
                    // Apple 2.3.1 (Accurate Metadata) reject risk + user 1-star.
                    // All rows below correspond to real gates verified in code:
                    //   * unlimited sessions  -> SessionStore.freeDailySessionLimit
                    //   * advanced techniques -> FocusPreset premium cases (.requiresPremium)
                    //   * custom durations    -> FocusPreset.custom.requiresPremium
                    //   * unlimited tags      -> ProjectTagPicker addTagButton gate
                    //   * Pomodoro autopilot  -> SessionStore.freeAutoCycleCount (free
                    //     gets ONE focus+break; multi-loop / loop-forever is Pro, via
                    //     clampedAutoCycleCount(isPremium:) + the Settings cycle picker)
                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity",               LocalizedStringKey("Unlimited daily sessions"))
                        techniquesFeatureRow
                        feature("repeat.circle.fill",     LocalizedStringKey("Pomodoro autopilot — chain multiple focus + break cycles automatically"))
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

    // MARK: - Honest price anchor (Pattern D)

    /// A single honest, generic, undated value-anchor line. No "launch pricing"
    /// (perishable + false once past launch), no fabricated install/rating
    /// counts (lessons #44/#53) — just the true pay-once-vs-subscription wedge
    /// that is the buying emotion in this category.
    private var priceAnchor: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.tint)
            Text(LocalizedStringKey("Most focus apps subscribe. This is one payment — forever. No subscription, no ads, ever."))
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
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
            // Apple 2.1(b): never an indefinite spinner. IAPManager bounds the
            // product load (productsLoadTimeout); once it resolves we surface a
            // retry + "keep using free" escape instead of a phantom ProgressView.
            unavailableFallback
        }
    }

    /// Graceful, user-actionable fallback that REPLACES a bare indefinite
    /// ProgressView (Apple 2.1(b) "loading forever"). After
    /// IAPManager.productsLoadTimeout the load resolves, so the reviewer/user
    /// always sees a retry + a "continue free" path.
    @ViewBuilder
    private var unavailableFallback: some View {
        switch iap.loadingState {
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(LocalizedStringKey("Loading products…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .loaded, .empty, .timedOut, .failed:
            VStack(spacing: 12) {
                Text(LocalizedStringKey("Products are temporarily unavailable. You can continue using FocusFlow for free, or try again later."))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await iap.loadProducts() }
                } label: {
                    Label(LocalizedStringKey("Try again"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    dismiss()
                } label: {
                    Text(LocalizedStringKey("Continue without subscription"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Technique-count feature row with a DYNAMIC count (premiumLibrary.count)
    /// so the paywall can never drift from the catalog the way the old static
    /// "8 techniques" string did (audit P0: paywall said 8; 7 premium exist).
    private var techniquesFeatureRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(String(format: String(localized: "paywall.techniques.feature"),
                        FocusPreset.premiumLibrary.count))
            Spacer()
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
