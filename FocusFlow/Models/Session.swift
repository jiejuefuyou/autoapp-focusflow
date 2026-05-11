import Foundation
import SwiftUI

/// A completed (or in-progress) focus block.
///
/// v1 persists as JSON in `UserDefaults` (no SwiftData) for simplicity —
/// re-evaluate when the history list grows beyond ~1k entries.
struct FocusSession: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var completedAt: Date?
    var duration: TimeInterval     // seconds (planned length)
    var actualDuration: TimeInterval  // seconds actually focused (== duration on completion, < on early stop)
    var tagId: UUID?               // links to ProjectTag.id; nil = "No tag"
    var completed: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        duration: TimeInterval,
        actualDuration: TimeInterval = 0,
        tagId: UUID? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.actualDuration = actualDuration
        self.tagId = tagId
        self.completed = completed
    }
}

/// A user-assignable project tag.
///
/// The 4 defaults (Work / Writing / Learning / Personal) ship pre-seeded so a
/// brand-new install has tags to choose from immediately. `localizationKey` is
/// the English source string that gets resolved through `Localizable.strings`
/// for the default tags; user-created tags use the literal `name` (no lookup).
struct ProjectTag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String   // "#RRGGBB" — Color(hex:) extension below
    var emoji: String
    var localizationKey: String?  // non-nil only for the 4 defaults

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        emoji: String,
        localizationKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
        self.localizationKey = localizationKey
    }

    /// Display name resolved through `Localizable.strings` for the 4 defaults,
    /// or the literal user-supplied name otherwise.
    var displayName: LocalizedStringKey {
        if let key = localizationKey {
            return LocalizedStringKey(key)
        }
        return LocalizedStringKey(name)
    }

    var color: Color { Color(hex: colorHex) }
}

extension ProjectTag {
    /// 4 default tags seeded on first launch.
    ///
    /// Free tier shows only the first 3; Premium unlocks all + custom tags.
    static let defaults: [ProjectTag] = [
        ProjectTag(name: "Work",     colorHex: "#3478F6", emoji: "💼", localizationKey: "Work"),
        ProjectTag(name: "Writing",  colorHex: "#AF52DE", emoji: "✍️", localizationKey: "Writing"),
        ProjectTag(name: "Learning", colorHex: "#34C759", emoji: "📚", localizationKey: "Learning"),
        ProjectTag(name: "Personal", colorHex: "#FF9500", emoji: "🌱", localizationKey: "Personal"),
    ]
}

/// Hard-coded preset durations + a "custom" affordance (Premium-gated in UI).
enum FocusPreset: String, CaseIterable, Identifiable, Codable, Hashable {
    case short25 = "25"
    case medium50 = "50"
    case long90 = "90"
    case custom = "custom"

    var id: String { rawValue }

    /// Default seconds. `.custom` returns 0 — callers must supply an explicit
    /// duration via `startSession(duration:tagId:)`.
    var seconds: TimeInterval {
        switch self {
        case .short25:  return 25 * 60
        case .medium50: return 50 * 60
        case .long90:   return 90 * 60
        case .custom:   return 0
        }
    }

    /// Whether this preset requires Premium entitlement.
    var requiresPremium: Bool {
        self == .custom
    }
}

// MARK: - Color hex helper

extension Color {
    /// Initialize from "#RRGGBB" or "RRGGBB". Falls back to `.gray` on malformed input.
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let int = UInt32(trimmed, radix: 16) else {
            self = .gray
            return
        }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
