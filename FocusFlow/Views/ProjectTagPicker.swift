import SwiftUI
import UIKit

/// Bottom sheet shown right after a session completes. The user taps a tag
/// (or "No tag") and the choice gets attached to the just-finished session.
///
/// Free tier sees the first 3 default tags. Premium unlocks all 4 + a
/// "Add tag" affordance.
struct ProjectTagPicker: View {
    @Environment(SessionStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    /// The session that just completed — picker writes the tag back via
    /// `store.assignTag(_, toSessionId:)`.
    let sessionId: UUID

    @State private var showAddTagSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 12) {
                        ForEach(visibleTags) { tag in
                            tagRow(tag)
                        }

                        noTagRow

                        if iap.isPremium {
                            addTagButton
                        } else if store.tags.count > store.availableTags(isPremium: false).count {
                            premiumHintRow
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(Text(LocalizedStringKey("Pick a tag")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Skip")) {
                        store.dismissPendingTag()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddTagSheet) {
                AddTagSheet { newTag in
                    store.addTag(newTag)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(LocalizedStringKey("Focus complete!"))
                .font(.title2.bold())
            Text(LocalizedStringKey("Tag this session so you can see where your time went."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var visibleTags: [ProjectTag] {
        store.availableTags(isPremium: iap.isPremium)
    }

    private func tagRow(_ tag: ProjectTag) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.assignTag(tag.id, toSessionId: sessionId)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(tag.emoji).font(.title2)
                Text(tag.displayName)
                    .font(.body.weight(.medium))
                Spacer()
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .foregroundStyle(.primary)
    }

    private var noTagRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            store.assignTag(nil, toSessionId: sessionId)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "minus.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey("No tag"))
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .foregroundStyle(.primary)
    }

    private var addTagButton: some View {
        Button {
            showAddTagSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(LocalizedStringKey("Add tag"))
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .foregroundStyle(.primary)
    }

    private var premiumHintRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("More tags with Pro"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

// MARK: - Add tag sheet (Premium)

private struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onCreate: (ProjectTag) -> Void

    @State private var name: String = ""
    @State private var emoji: String = "📁"
    @State private var colorHex: String = "#5856D6"

    /// 8 preset colors users can pick from. Keep the palette tight so the
    /// charts don't end up unreadable.
    private let palette: [String] = [
        "#3478F6", "#AF52DE", "#34C759", "#FF9500",
        "#FF3B30", "#5856D6", "#FF2D55", "#A2845E",
    ]

    /// Common emoji set; user can also paste any single character into the text field.
    private let emojiOptions: [String] = ["💼", "✍️", "📚", "🌱", "🎨", "🏋️", "🎵", "🧘", "📁"]

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("Name")) {
                    TextField(LocalizedStringKey("Tag name"), text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section(LocalizedStringKey("Emoji")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button {
                                emoji = e
                            } label: {
                                Text(e)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        emoji == e ? Color.accentColor.opacity(0.25) : Color.clear,
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section(LocalizedStringKey("Color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("Add tag")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Save")) {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let tag = ProjectTag(name: trimmed, colorHex: colorHex, emoji: emoji)
                        onCreate(tag)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
