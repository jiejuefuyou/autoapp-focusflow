import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// A polished, shareable focus-stats card rendered to an image for organic
/// virality. Shows the user's focus highlights — today, this week, and current
/// streak — with clear app attribution so every share doubles as a referral.
///
/// Rendered off-screen via `ImageRenderer`, so it takes only plain value types
/// (no `@Environment`): `ImageRenderer` builds a detached view tree, and
/// pre-resolving localized strings on the call site keeps the in-app language
/// override (the swizzled `Bundle.main`) authoritative for the rendered text.
struct FocusShareCard: View {
    /// Pre-resolved, localized label strings (resolved by the caller so the
    /// in-app language override applies to the rendered image).
    struct Labels {
        let title: String        // app name, e.g. "FocusFlow"
        let tagline: String      // e.g. "Deep focus, unblocked."
        let today: String        // "Today"
        let thisWeek: String     // "This Week"
        let streak: String       // "Day streak" (unit-free count shown as the value)
        let footer: String       // attribution / call-to-action line
    }

    let todayFormatted: String
    let weekFormatted: String
    let streakDays: Int
    let labels: Labels

    /// Fixed card size — a 3:4 portrait tile that reads well in stories, chat,
    /// and feed previews. `ImageRenderer` captures exactly this frame.
    static let cardSize = CGSize(width: 1080, height: 1350)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.78),
                    Color.accentColor.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 56) {
                header
                Spacer(minLength: 0)
                statsBlock
                Spacer(minLength: 0)
                footer
            }
            .padding(96)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 28) {
            Image(systemName: "timer")
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 132, height: 132)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 32))
            VStack(alignment: .leading, spacing: 8) {
                Text(labels.title)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(labels.tagline)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var statsBlock: some View {
        VStack(spacing: 40) {
            statRow(value: todayFormatted, label: labels.today, icon: "flame.fill")
            divider
            statRow(value: weekFormatted, label: labels.thisWeek, icon: "calendar")
            divider
            statRow(value: "\(streakDays)", label: labels.streak, icon: "bolt.fill")
        }
        .padding(64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 48))
    }

    private func statRow(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 36) {
            Image(systemName: icon)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(value)
                    .font(.system(size: 76, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.22))
            .frame(height: 2)
    }

    private var footer: some View {
        Text(labels.footer)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Shareable image transfer

/// A PNG-backed image wrapper that is both `Identifiable` (so it can drive a
/// `.sheet(item:)`) and `Transferable` (so `ShareLink` can export it to Photos,
/// Messages, etc.). Carries the raw PNG bytes produced by `ImageRenderer`.
struct ShareableImage: Identifiable, Transferable {
    let id = UUID()
    let data: Data

    /// Suggested filename stem for exports (recipients see "FocusFlow.png").
    static let exportName = "FocusFlow"

    var uiImage: UIImage? { UIImage(data: data) }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { value in
            value.data
        }
        .suggestedFileName("\(exportName).png")
    }
}

// MARK: - Preview-and-share sheet

/// Shows the rendered focus-stats card and a `ShareLink` to send it. Giving the
/// user a preview before sharing (rather than dumping straight into the system
/// share sheet) makes the moment feel intentional and on-brand.
struct ShareStatsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let card: ShareableImage

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let uiImage = card.uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                            .padding(.horizontal)
                            .accessibilityLabel(Text(LocalizedStringKey("Your focus stats card")))
                    }

                    ShareLink(
                        item: card,
                        preview: SharePreview(
                            Text(LocalizedStringKey("FocusFlow")),
                            image: previewImage
                        )
                    ) {
                        Label(LocalizedStringKey("Share"), systemImage: "square.and.arrow.up")
                            .font(Typography.bodyEmphasis)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Radius.lg))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("share.cta")
                }
                .padding(.vertical, Spacing.lg)
            }
            .navigationTitle(Text(LocalizedStringKey("Share focus stats")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
        }
    }

    /// Thumbnail for the share-sheet preview header. Falls back to an SF Symbol
    /// if the PNG can't be decoded (it always should).
    private var previewImage: Image {
        if let uiImage = card.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "timer")
    }
}
