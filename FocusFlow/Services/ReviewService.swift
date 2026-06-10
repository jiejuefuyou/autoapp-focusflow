//  ReviewService.swift — PORTFOLIO CANONICAL (orchestrator/ios-core)
//
//  Single source of truth for all autoapp iOS apps. DO NOT edit per-app copies.
//  Edit orchestrator/ios-core/swift/ReviewService.swift, then run:
//      python dashboard/sync_ios_core.py --apply
//  Drift is gated by dashboard/audit_portfolio.py (core-sync check).
//
import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewService {
    private static let actionCountKey = "review.actionCount"
    private static let actionsAtLastRequestKey = "review.actionsAtLastRequest"
    private static let lastRequestKey = "review.lastRequestDate"
    private static let firstActionKey = "review.firstActionDate"

    private static let minActionsBeforeFirstAsk = 5
    private static let minActionsBetweenAsks = 30
    private static let minDaysBetweenAsks = 122
    private static let minDaysSinceFirstAction = 3

    /// Call after a user-meaningful success (spin completed, session saved, event added).
    static func recordSuccess() {
        let d = UserDefaults.standard
        if d.object(forKey: firstActionKey) == nil {
            d.set(Date(), forKey: firstActionKey)
        }
        d.set(d.integer(forKey: actionCountKey) + 1, forKey: actionCountKey)
    }

    /// Conditionally show Apple's review prompt. Returns true if attempted.
    @discardableResult
    static func maybeRequestReview() -> Bool {
        let d = UserDefaults.standard
        let count = d.integer(forKey: actionCountKey)
        guard count >= minActionsBeforeFirstAsk else { return false }

        if let firstAction = d.object(forKey: firstActionKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: firstAction, to: Date()).day ?? 0
            guard days >= minDaysSinceFirstAction else { return false }
        }

        if let last = d.object(forKey: lastRequestKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if days < minDaysBetweenAsks { return false }
            let snapshot = d.integer(forKey: actionsAtLastRequestKey)
            if (count - snapshot) < minActionsBetweenAsks { return false }
        }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return false }

        AppStore.requestReview(in: scene)
        d.set(Date(), forKey: lastRequestKey)
        d.set(count, forKey: actionsAtLastRequestKey)
        return true
    }
}
