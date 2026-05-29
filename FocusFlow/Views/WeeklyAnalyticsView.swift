import SwiftUI
import Charts

/// Last-7-days analytics: total focus minutes per day (line) + minutes per tag
/// (bar). Uses native Swift Charts (`import Charts`), iOS 17+ only.
struct WeeklyAnalyticsView: View {
    @Environment(SessionStore.self) private var store

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
            }
            .padding(Spacing.md)
        }
        .navigationTitle(Text(LocalizedStringKey("This Week")))
        .navigationBarTitleDisplayMode(.large)
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
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
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
