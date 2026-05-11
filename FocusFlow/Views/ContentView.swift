import SwiftUI

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(SessionStore.self) private var store

    @State private var showStartSheet = false
    @State private var showSettings = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let session = store.currentSession {
                    activeView(session: session)
                } else {
                    idleView
                }
            }
            .padding()
            .navigationTitle("FocusFlow")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !iap.isPremium {
                        Button { showPaywall = true } label: {
                            Label("Pro", systemImage: "sparkles").font(.caption.bold())
                        }
                    }
                }
            }
            .sheet(isPresented: $showStartSheet) {
                StartSessionSheet { preset, label, tag in
                    if !iap.isPremium && store.sessionsToday() >= SessionStore.freeDailySessionLimit {
                        showPaywall = true
                        return
                    }
                    store.startSession(preset: preset, label: label, tag: tag)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Ready to focus")
                .font(.title2.bold())

            if !iap.isPremium {
                Text("Free: \(store.sessionsToday()) / \(SessionStore.freeDailySessionLimit) sessions today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                if !iap.isPremium && store.sessionsToday() >= SessionStore.freeDailySessionLimit {
                    showPaywall = true
                } else {
                    showStartSheet = true
                }
            } label: {
                Label("Start Session", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)

            if !store.history.isEmpty {
                Spacer().frame(height: 16)
                recentSessions
            }
        }
    }

    @ViewBuilder
    private func activeView(session: FocusSession) -> some View {
        VStack(spacing: 24) {
            Text(session.label)
                .font(.title.bold())
            if let tag = session.tag {
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.15), in: Capsule())
            }

            Text(formatTime(store.timeRemaining))
                .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.tint)

            HStack(spacing: 24) {
                Button(role: .destructive) {
                    store.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                }

                if store.isRunning {
                    Button {
                        store.pause()
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 60))
                    }
                } else {
                    Button {
                        store.resume()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                    }
                }
            }
        }
        .padding()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
            ForEach(todaysSessions) { session in
                HStack {
                    Image(systemName: session.completed ? "checkmark.circle.fill" : "clock")
                        .foregroundStyle(session.completed ? .green : .orange)
                    Text(session.label)
                    Spacer()
                    Text("\(Int(session.duration / 60)) min")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var todaysSessions: [FocusSession] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return store.history.filter { cal.startOfDay(for: $0.startedAt) == today }.reversed()
    }

    private func formatTime(_ s: TimeInterval) -> String {
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - StartSessionSheet

struct StartSessionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var tag: String = ""
    @State private var preset: FocusPreset = .pomodoro25

    let onStart: (FocusPreset, String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset") {
                    Picker("Length", selection: $preset) {
                        ForEach(FocusPreset.allCases) { p in
                            Label(p.rawValue, systemImage: p.symbol).tag(p)
                        }
                    }
                }
                Section("Label") {
                    TextField("e.g. Coding, Writing", text: $label)
                    TextField("Tag (optional, e.g. project-x)", text: $tag)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Start Focus")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") {
                        let trimmedLabel = label.trimmingCharacters(in: .whitespaces).isEmpty ? "Focus" : label
                        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
                        onStart(preset, trimmedLabel, trimmedTag.isEmpty ? nil : trimmedTag)
                        dismiss()
                    }
                }
            }
        }
    }
}
