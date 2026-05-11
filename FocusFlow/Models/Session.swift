import Foundation

struct FocusSession: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var duration: TimeInterval  // seconds (e.g. 25 * 60 for Pomodoro)
    var label: String           // e.g. "Coding", "Writing", "Reading"
    var tag: String?            // optional project tag
    var completed: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        duration: TimeInterval,
        label: String,
        tag: String? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.label = label
        self.tag = tag
        self.completed = completed
    }
}

enum FocusPreset: String, CaseIterable, Identifiable {
    case pomodoro25 = "25 min Pomodoro"
    case shortDeep = "45 min Deep Focus"
    case longDeep = "90 min Deep Work"
    case break5 = "5 min Break"
    case break15 = "15 min Long Break"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .pomodoro25: return 25 * 60
        case .shortDeep:  return 45 * 60
        case .longDeep:   return 90 * 60
        case .break5:     return 5 * 60
        case .break15:    return 15 * 60
        }
    }

    var symbol: String {
        switch self {
        case .pomodoro25: return "timer"
        case .shortDeep:  return "brain.head.profile"
        case .longDeep:   return "infinity"
        case .break5, .break15: return "cup.and.saucer.fill"
        }
    }
}
