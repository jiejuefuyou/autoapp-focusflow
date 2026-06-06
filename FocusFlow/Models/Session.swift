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

/// Curated library of named focus techniques + a "custom" affordance
/// (Premium-gated in UI).
///
/// **Backward compatibility (v1.0.x):** the four original cases keep their exact
/// `rawValue`s (`"25"`, `"50"`, `"90"`, `"custom"`) and the same `seconds`, so any
/// persisted selection or `@SceneStorage`/`UserDefaults` round-trip stays valid.
/// `FocusSession` only persists `duration` (seconds), never a `FocusPreset`, so
/// this enrichment cannot corrupt history. The five premium cases are purely
/// additive.
///
/// Each preset exposes `focusMinutes` / `breakMinutes` as descriptive metadata.
/// The timer continues to run on the focus duration alone (`seconds`); break
/// minutes are surfaced in the picker subtitle and are not yet consumed by the
/// countdown — kept as data so a future "auto-break" feature is additive.
enum FocusPreset: String, CaseIterable, Identifiable, Codable, Hashable {
    // ── Free tier (original three — rawValues + durations unchanged) ──
    case short25 = "25"
    case medium50 = "50"
    case long90 = "90"

    // ── Premium tier (additive, v1.0.x curated techniques) ──
    case deskTime5217 = "deskTime5217"
    case studySprint45 = "studySprint45"
    case examCram60 = "examCram60"
    case writingFlow50 = "writingFlow50"
    case quickSprint15 = "quickSprint15"
    case flowState75 = "flowState75"
    case windDown20 = "windDown20"

    // ── Custom-duration affordance (rawValue unchanged) ──
    case custom = "custom"

    var id: String { rawValue }

    /// Focus length in minutes (the work block).
    var focusMinutes: Int {
        switch self {
        case .short25:       return 25
        case .medium50:      return 50
        case .long90:        return 90
        case .deskTime5217:  return 52
        case .studySprint45: return 45
        case .examCram60:    return 60
        case .writingFlow50: return 50
        case .quickSprint15: return 15
        case .flowState75:   return 75
        case .windDown20:    return 20
        case .custom:        return 0
        }
    }

    /// Suggested break length in minutes (descriptive — not consumed by the
    /// countdown yet). `.custom` has no prescribed break.
    var breakMinutes: Int {
        switch self {
        case .short25:       return 5
        case .medium50:      return 10
        case .long90:        return 20
        case .deskTime5217:  return 17
        case .studySprint45: return 10
        case .examCram60:    return 10
        case .writingFlow50: return 15
        case .quickSprint15: return 5
        case .flowState75:   return 15
        case .windDown20:    return 10
        case .custom:        return 0
        }
    }

    /// Focus-block seconds — the value the timer actually starts with.
    /// `.custom` returns 0; callers supply an explicit duration via
    /// `startSession(duration:tagId:)`.
    ///
    /// Derived from `focusMinutes` so the original three still resolve to
    /// 25/50/90 min exactly.
    var seconds: TimeInterval {
        TimeInterval(focusMinutes * 60)
    }

    /// `Localizable.strings` key for the technique's display name.
    /// `.custom` is rendered by the dedicated custom chip, so it has no key.
    var nameKey: String {
        switch self {
        case .short25:       return "preset.classic.name"
        case .medium50:      return "preset.longFocus.name"
        case .long90:        return "preset.deepWork.name"
        case .deskTime5217:  return "preset.deskTime.name"
        case .studySprint45: return "preset.studySprint.name"
        case .examCram60:    return "preset.examCram.name"
        case .writingFlow50: return "preset.writingFlow.name"
        case .quickSprint15: return "preset.quickSprint.name"
        case .flowState75:   return "preset.flowState.name"
        case .windDown20:    return "preset.windDown.name"
        case .custom:        return "Custom"
        }
    }

    /// `Localizable.strings` key for the one-sentence technique description
    /// shown as the chip subtitle.
    var descriptionKey: String {
        switch self {
        case .short25:       return "preset.classic.desc"
        case .medium50:      return "preset.longFocus.desc"
        case .long90:        return "preset.deepWork.desc"
        case .deskTime5217:  return "preset.deskTime.desc"
        case .studySprint45: return "preset.studySprint.desc"
        case .examCram60:    return "preset.examCram.desc"
        case .writingFlow50: return "preset.writingFlow.desc"
        case .quickSprint15: return "preset.quickSprint.desc"
        case .flowState75:   return "preset.flowState.desc"
        case .windDown20:    return "preset.windDown.desc"
        case .custom:        return ""
        }
    }

    /// Whether this preset requires Premium entitlement.
    /// Free = the three original techniques; Premium = the five curated ones
    /// plus the custom-duration affordance.
    var requiresPremium: Bool {
        switch self {
        case .short25, .medium50, .long90:
            return false
        case .deskTime5217, .studySprint45, .examCram60, .writingFlow50,
             .quickSprint15, .flowState75, .windDown20, .custom:
            return true
        }
    }

    /// The named techniques shown in the picker library (everything except the
    /// custom-duration affordance, which has its own chip).
    static let library: [FocusPreset] = [
        .short25, .medium50, .long90,
        .deskTime5217, .studySprint45, .examCram60, .writingFlow50,
        .quickSprint15, .flowState75, .windDown20,
    ]

    /// The premium techniques in the library, computed (never hardcoded) so the
    /// "unlock all N" copy and the trial accounting stay in sync as the catalog
    /// grows. Excludes `.custom`, which has its own dedicated chip.
    static var premiumLibrary: [FocusPreset] {
        library.filter(\.requiresPremium)
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
