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

                    // ── Feature list — ONLY shipped features ──
                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity",               LocalizedStringKey("Unlimited daily sessions"))
                        feature("calendar",               LocalizedStringKey("Full history — 7, 30, and 90 days"))
                        feature("chart.bar.fill",         LocalizedStringKey("Detailed analytics by project tag"))
                        feature("tag.fill",               LocalizedStringKey("Unlimited project tags with emoji + color"))
                        feature("slider.horizontal.3",   LocalizedStringKey("Custom session durations (any length)"))
                        feature("square.and.arrow.up",   LocalizedStringKey("Export session data to CSV"))
                        feature("moon.fill",              LocalizedStringKey("Focus Filter — auto-start sessions when iOS Focus turns on"))
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
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .disabled(iap.purchaseInProgress)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    // MARK: - Feature row

    private func feature(_ icon: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 28)
            Text(label)
            Spacer()
        }
    }

    // MARK: - Legalese

    private var legalese: String {
        "Payment will be charged to your Apple ID. This is a one-time purchase that unlocks all premium features for the lifetime of your Apple ID."
    }
}
