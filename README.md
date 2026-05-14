---
id: focusflow
title: FocusFlow (iOS) - Focus Timer with Project Tags
category: new-ios-app
priority: P0
status: in-development
revenue_jpy_month: "19600-39200"
actions: [open-editor, run-script]
tags: [ios, swiftui, pomodoro, project-tags, deep-work]
ice_score: 5.8
tier_price_usd: "3.99"
tier_price_jpy: 600
command: "cd repos/autoapp-focusblock && xcodegen generate"
created: 2026-05-06
renamed: 2026-05-11 (FocusBlock → FocusFlow, repositioning per cluster A analysis)
---
# FocusFlow

Focus timer with project tags — track deep work by tag, see weekly analytics, single-tap to start.

**Differentiation**: Forest 简洁 + Toggl 标签复盘 + ¥600 ($3.99) 永久解锁。iOS 17 Focus Filter — planned v1.1.

## Status

🟢 **In Development** (2026-05-11, SDD execution tick #166B continuation). Target v1.0 ship within 2 weeks.

Requires:
1. `xcodegen generate` to create .xcodeproj
2. App icon (1024×1024)
3. ASC IAP setup (`com.jiejuefuyou.focusflow.premium`)
4. Submit to ASC

## Target Audience (Cluster A — Power User + Anti-subscription)

- **ICP 1**: Indie developers / freelancers (deep focus + project tracking)
- **ICP 2**: Knowledge workers (Notion / Obsidian users + writers + consultants)
- **ICP 3**: Researchers / students (study session analytics)
- **ICP 4**: Anti-subscription productivity tool collectors (lifetime IAP preferred over SaaS bloat)

## Free vs Premium

```
Free tier:
  - Quick timer (25/50/90 preset)
  - 3 project tags
  - Today's session record
  - System DND toggle (manual)

Premium ($3.99 one-time, com.jiejuefuyou.focusflow.premium):
  - Unlimited daily sessions
  - Full history — 7, 30, and 90-day views
  - Detailed analytics by project tag
  - Unlimited custom project tags (emoji + color)
  - Custom session durations (any length)
  - Export session data to CSV
  --- v1.1 roadmap (not in v1.0) ---
  - Auto Focus Filter API integration (iOS 17+)
  - Lock screen widget (WidgetKit)
  - Apple Watch companion
```

## File structure (post-rename 2026-05-11)

```
FocusFlow/
├── App/FocusFlowApp.swift              # @main + state injection
├── IAP/IAPManager.swift                # StoreKit 2 with 5s timeout (per CLAUDE.md 5)
├── Models/Session.swift                # FocusSession + FocusPreset + ProjectTag
├── Services/SessionStore.swift         # @Observable + Timer + UserDefaults
└── Views/
    ├── ContentView.swift               # Idle / Active / Recent sessions
    ├── OnboardingView.swift            # 3-page + Skip button (UX standards P0)
    ├── PaywallView.swift               # IAP unlock UI with timeout fallback
    ├── SettingsView.swift              # Language picker + cross-promo + Premium
    └── ScaleButtonStyle.swift          # Custom button press feedback
```

## ASC setup checklist

```
1. ASC → My Apps → + New App
   Bundle ID: com.jiejuefuyou.focusflow
   Name: FocusFlow
   SKU: focusflow-001

2. Add IAP:
   Reference Name: focusflow_premium_unlock
   Product ID: com.jiejuefuyou.focusflow.premium
   Type: Non-Consumable
   Price: $3.99 USD (Tier 5 — approx ¥600 JP at current Apple tier)

3. Pricing: Free download
4. Category: Productivity
5. Localizations: 8 lang (en/ja/zh-Hans/zh-Hant/ko/es/fr/de) per CLAUDE.md 14b
```

## Differentiation (vs red ocean)

| Competitor | Price | Their Strength | FocusFlow Wedge |
|---|---|---|---|
| Forest | $3.99 | Gamification | No gamification + weekly analytics by tag |
| Be Focused | ¥600/yr sub | iCloud sync | ¥980 lifetime (no subscription) |
| Focus Commit | $9.99 / ¥1500 | Cross-platform | iOS 17 native Focus Filter + ¥520 cheaper |
| Toggl | Free/sub | Time tracking | Lightweight focus block launcher + ¥980 lifetime |

## ASO

```
Title:    FocusFlow: Project Focus Timer
Subtitle: Focus timer with project tags
Keywords: pomodoro,focus,timer,productivity,deep work,project,tags,analytics,dnd
```

## Day 30 revenue projection

Based on PromptVault + DaysUntil benchmarks:

```
20-40 paid IAP × ¥980 = ¥19,600 - ¥39,200/month
```

## Memory rules honored (per CLAUDE.md)

- ✅ § 14b — 8-lang i18n SOP (en/ja/zh-Hans/zh-Hant/ko/es/fr/de native idiom translation)
- ✅ § 14c — Cross-promo "More from Hao Sun" Settings section (4 other apps)
- ✅ § 16 — UX 4 mandatory standards (Skip / Language picker / 中文区分 / button feedback)
- ✅ § 5 — Paywall 5s timeout + graceful fallback
- ✅ § 4 — IAP product ID consistency 3-place check (Swift / StoreKit / ASC web)

## License

MIT (subject to change).

## Contact

Email: jiejuefuyou@gmail.com
