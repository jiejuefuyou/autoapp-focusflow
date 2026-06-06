import SwiftUI
import Charts
import UIKit

/// Last-7-days analytics: total focus minutes per day (line) + minutes per tag
/// (bar). Uses native Swift Charts (`import Charts`), iOS 17+ only.
struct WeeklyAnalyticsView: View {
    @Environment(SessionStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n

    /// Rendered share card, populated when the user taps Share. Drives the
    /// preview-and-share sheet (`nil` = no sheet).
    @State private var shareCard: ShareableImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {   // 28 = analytics card rhythm, between lg(24)/xl(32)
                summaryHeader

                Section {
                    lineChart
                } header: {
                    sectionHeader(LocalizedStringKey("Focus minutes per day"))
                }

                Section {
                    if tagBars.isEmpty {
                        emptyState
                    } else {
                        tagBarChart
                    }
                } header: {
                    sectionHeader(LocalizedStringKey("Minutes by tag"))
                }

                Section {
                    if hasHeatmapData {
                        heatmapChart
                    } else {
                        emptyState
                    }
                } header: {
                    sectionHeader(LocalizedStringKey("Best time of day"))
                }
            }
            .padding(Spacing.md)
        }
        .navigationTitle(Text(LocalizedStringKey("This Week")))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareCard = renderShareCard()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text(LocalizedStringKey("Share focus stats")))
            }
        }
        // Preview-and-share sheet (lesson #34 — re-inject l10n).
        .sheet(item: $shareCard) { card in
            ShareStatsSheet(card: card)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .id(l10n.override)
        }
    }

    // MARK: - Shareable stats card

    /// Render the branded `FocusShareCard` to a PNG via `ImageRenderer`.
    /// Strings are pre-resolved here so the rendered image honors the in-app
    /// language override (the swizzled `Bundle.main`).
    @MainActor
    private func renderShareCard() -> ShareableImage? {
        let labels = FocusShareCard.Labels(
            title: String(localized: "FocusFlow"),
            tagline: String(localized: "share.tagline"),
            today: String(localized: "Today"),
            thisWeek: String(localized: "This Week"),
            streak: String(localized: "share.streak"),
            footer: String(localized: "share.footer")
        )
        let card = FocusShareCard(
            todayFormatted: todayFormatted,
            weekFormatted: totalFormatted,
            streakDays: store.currentStreak,
            labels: labels
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1   // card is already authored at full pixel size
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else {
            return nil
        }
        return ShareableImage(data: data)
    }

    /// Total focused time today, formatted as "1h 35m" or "35m". Mirrors the
    /// Today-card math on the home screen so the share value matches what the
    /// user sees there.
    private var todayFormatted: String {
        let mins = store.todayFocusMinutes()
        let h = mins / 60
        let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(LocalizedStringKey("Total focus this week"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // 40pt hero display — fixed font weight intentional (not Dynamic Type, but visually closer to .largeTitle)
            Text(totalFormatted)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))   // 16 = analytics card; visual depends on this size
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.headline)
            .padding(.bottom, 2)
    }

    // MARK: - Line chart

    private var lineChart: some View {
        Chart(daily) { row in
            LineMark(
                x: .value("Day", row.date, unit: .day),
                y: .value("Minutes", row.minutes)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)
            .symbol {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }

            AreaMark(
                x: .value("Day", row.date, unit: .day),
                y: .value("Minutes", row.minutes)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(l10n.currentLocale))
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))   // 16 = analytics card matches summaryHeader
    }

    // MARK: - Bar chart

    private var tagBarChart: some View {
        Chart(tagBars) { row in
            BarMark(
                x: .value("Minutes", row.minutes),
                y: .value("Tag", row.label)
            )
            .foregroundStyle(row.color)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(row.minutes.rounded())) \(String(localized: "min"))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(120, tagBars.count * 40)))
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))   // 16 = analytics card
    }

    // MARK: - Best-time-of-day heatmap

    /// Compact 24-hour bar chart of all-time completed focus minutes, surfacing
    /// when the user focuses best. Bars are tinted by intensity (relative to the
    /// busiest hour) so peak hours read instantly. Uses the already-imported
    /// Swift Charts; no new dependency.
    private var heatmapChart: some View {
        Chart(hourly) { bucket in
            BarMark(
                x: .value("Hour", bucket.hour),
                y: .value("Minutes", bucket.minutes),
                width: .fixed(7)   // fixed px width: predictable on a 24-point continuous x-axis
            )
            .foregroundStyle(Color.accentColor.opacity(intensity(for: bucket.minutes)))
            .cornerRadius(2)
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            // Label every 6 hours (0 / 6 / 12 / 18) to keep the compact axis legible.
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(hourAxisLabel(hour))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 140)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))   // 16 = analytics card
        .overlay(alignment: .topTrailing) {
            if let peak = peakHourLabel {
                Text(peak)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("No focus sessions yet this week."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))   // 16 = analytics card
    }

    // MARK: - Derived

    private var daily: [DailyMinutes] {
        store.dailyMinutesLast7Days()
    }

    private var tagBars: [TagBarRow] {
        let byTag = store.minutesByTagLast7Days().filter { $0.minutes > 0 }
        return byTag.map { row in
            if let id = row.tagId, let tag = store.tag(forId: id) {
                return TagBarRow(
                    id: tag.id.uuidString,
                    label: "\(tag.emoji) " + resolveTagDisplay(tag),
                    minutes: row.minutes,
                    color: tag.color
                )
            }
            return TagBarRow(
                id: "untagged",
                label: NSLocalizedString("No tag", comment: ""),
                minutes: row.minutes,
                color: .gray
            )
        }
    }

    private var totalFormatted: String {
        let total = daily.reduce(0) { $0 + $1.minutes }
        let mins = Int(total.rounded())
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    // MARK: - Heatmap derived

    private var hourly: [HourBucket] {
        store.focusMinutesByHourOfDay()
    }

    private var hasHeatmapData: Bool {
        hourly.contains { $0.minutes > 0 }
    }

    /// Busiest hour's minutes — the denominator for bar intensity.
    private var peakMinutes: Double {
        hourly.map(\.minutes).max() ?? 0
    }

    /// Opacity for a bar relative to the busiest hour: empty hours stay faint,
    /// the peak hour reads full-strength. Range ≈ 0.18...1.0.
    private func intensity(for minutes: Double) -> Double {
        guard peakMinutes > 0, minutes > 0 else { return 0.18 }
        return 0.35 + 0.65 * (minutes / peakMinutes)
    }

    /// Short hour-of-day axis label, e.g. "6 AM" / "18:00" — formatted in the
    /// current locale via `DateComponents` so 12h/24h conventions are respected.
    private func hourAxisLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let cal = Calendar.current
        guard let date = cal.date(from: comps) ?? cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour)"
        }
        // `.formatted()` defaults to Locale.autoupdatingCurrent (the SYSTEM
        // language), so on a Japanese device it leaks Japanese hour labels
        // ("6時") into an app the user switched to Chinese. Pin every Date
        // format style to the in-app override locale so nothing leaks.
        return date.formatted(.dateTime.hour().locale(l10n.currentLocale))
    }

    /// "Peak: 9 AM" style annotation for the user's single busiest focus hour,
    /// or `nil` when there's no data.
    private var peakHourLabel: String? {
        guard let top = hourly.filter({ $0.minutes > 0 }).max(by: { $0.minutes < $1.minutes }) else {
            return nil
        }
        return String(format: NSLocalizedString("heatmap.peak", comment: "peak focus hour"),
                      hourAxisLabel(top.hour))
    }

    /// Resolve a tag's display name to a runtime String for use inside `Chart`
    /// label values (which don't accept `LocalizedStringKey` directly).
    private func resolveTagDisplay(_ tag: ProjectTag) -> String {
        if let key = tag.localizationKey {
            return NSLocalizedString(key, comment: "")
        }
        return tag.name
    }
}

// MARK: - Bar row helper

private struct TagBarRow: Identifiable, Hashable {
    let id: String
    let label: String
    let minutes: Double
    let color: Color
}
