// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A plain row with a highlight shape: 36 pt high, 24 pt symbol column.
struct MenuRow: View {
    enum Hint {
        case keys(String)
        case chevron
        case checkmark
    }

    let title: Text
    let symbol: String
    let hint: Hint?
    let isDestructive: Bool
    let isFocused: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: symbol)
                    .frame(width: 24, alignment: .leading)
                title
                    .lineLimit(1)
                Spacer(minLength: AppSpacing.s)
                hintView
                    .font(.subheadline)
                    .foregroundStyle(isFocused ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
            .font(.body)
            .foregroundStyle(isFocused ? AnyShapeStyle(.white) : isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background {
                if isFocused {
                    RoundedRectangle(cornerRadius: AppMetrics.rowHighlightRadius, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
            .contentShape(.rect)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    @ViewBuilder private var hintView: some View {
        switch hint {
        case .keys(let keys):
            Text(verbatim: keys)
        case .chevron:
            Image(systemName: "chevron.right")
                .accessibilityHidden(true)
        case .checkmark:
            Image(systemName: "checkmark")
                .accessibilityLabel("Current")
        case nil:
            EmptyView()
        }
    }
}

/// The one prominent button in the panel, with a ring when it has the focus.
struct ResumeRow: View {
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: "play.fill")
                    .frame(width: 24, alignment: .leading)
                Text("Resume")
                Spacer(minLength: AppSpacing.s)
                Text(verbatim: "esc")
                    .font(.subheadline)
                    .opacity(0.8)
            }
            .font(.body)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .focusable(false)
        .overlay {
            if isFocused {
                Capsule()
                    .strokeBorder(.white.opacity(0.85), lineWidth: 3)
                    .padding(-5)
                    .allowsHitTesting(false)
            }
        }
        // Keeps the ring inside the scroll view, which would clip it.
        .padding(5)
    }
}

/// 8 pt gap with a hairline between row groups.
struct GroupDivider: View {
    var body: some View {
        PanelDivider()
            .padding(.vertical, AppSpacing.xs)
    }
}

// MARK: - Save state slot

struct SlotView: View {
    let slot: Int
    let state: SaveStateSlot?
    /// Why the state may not load as expected; shown as a warning.
    let issues: [SaveStateIssue]
    let isFocused: Bool
    let showsFocus: Bool
    let save: () -> Void
    let load: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    private let radius = AppMetrics.artworkRadius

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            thumbnail
                .padding(.bottom, AppSpacing.xs)
            (state?.name.map { Text(verbatim: $0) } ?? Text("Slot \(slot)"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .help(state?.name.map { String(localized: "Slot \(slot): \($0)") } ?? "")
            HStack(spacing: AppSpacing.xxs) {
                if !issues.isEmpty {
                    Image(systemName: StatusKind.warning.defaultSymbol)
                        .foregroundStyle(StatusKind.warning.color)
                        .accessibilityHidden(true)
                }
                Text(state.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? String(localized: "Empty"))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(issueText ?? "")
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(verbatim: issueText ?? ""))
            // Shown on the focused slot (the pointer moves the focus), so
            // nothing is context-menu-only.
            HStack(spacing: AppSpacing.s) {
                Button("Save", action: save)
                Button("Load", action: load)
                    .disabled(state == nil)
                Spacer(minLength: 0)
                Button("Rename…", systemImage: "pencil", action: rename)
                    .labelStyle(.iconOnly)
                    .disabled(state?.canRename != true)
                    .help("Rename…")
                Button("Delete…", systemImage: "trash", action: delete)
                    .labelStyle(.iconOnly)
                    .disabled(state == nil)
                    .help("Delete…")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.top, AppSpacing.xs)
            .opacity(isFocused ? 1 : 0)
        }
        .contentShape(.rect)
        .contextMenu {
            Button("Save", action: save)
            Button("Load", action: load)
                .disabled(state == nil)
            Button("Rename…", action: rename)
                .disabled(state?.canRename != true)
            Divider()
            Button("Delete…", role: .destructive, action: delete)
                .disabled(state == nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state?.name.map { Text("Slot \(slot): \($0)") } ?? Text("Slot \(slot)"))
    }

    private var issueText: String? {
        issues.isEmpty ? nil : issues.map(\.summary).joined(separator: " ")
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.white.opacity(0.06))
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                if let state {
                    ArtworkImage(url: state.thumbnailURL, maxPixel: 320, contentMode: .fill) { Color.clear }
                        .id(state.date)
                } else {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .artworkFrame(radius: radius)
            .overlay {
                if isFocused, showsFocus {
                    let inset = AppMetrics.selectionRingGap + AppMetrics.selectionRingWidth
                    RoundedRectangle(cornerRadius: radius + inset, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: AppMetrics.selectionRingWidth)
                        .padding(-inset)
                }
            }
    }
}

// MARK: - History

/// A replaced or deleted state: thumbnail, where it was, when it was
/// replaced, and Load / Restore / Delete on the focused row.
struct HistoryRow: View {
    let entry: SaveStateSlot
    let issues: [SaveStateIssue]
    let isFocused: Bool
    let load: () -> Void
    let restore: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            RoundedRectangle(cornerRadius: AppMetrics.smallArtworkRadius, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: 64, height: 48)
                .overlay {
                    ArtworkImage(url: entry.thumbnailURL, maxPixel: 160, contentMode: .fill) { Color.clear }
                }
                .clipShape(.rect(cornerRadius: AppMetrics.smallArtworkRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(verbatim: [entry.slotTitle, entry.name].compactMap { $0 }.joined(separator: " · "))
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: AppSpacing.xxs) {
                    if !issues.isEmpty {
                        Image(systemName: StatusKind.warning.defaultSymbol)
                            .foregroundStyle(StatusKind.warning.color)
                            .accessibilityHidden(true)
                    }
                    Text("Replaced \((entry.replaced ?? entry.date).formatted(.relative(presentation: .named)))")
                }
                .font(.caption)
                .foregroundStyle(isFocused ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                .help(Text("Saved \(entry.date.formatted(date: .abbreviated, time: .shortened))"))
            }
            Spacer(minLength: AppSpacing.s)
            HStack(spacing: AppSpacing.s) {
                Button("Load", action: load)
                Button(restoreTitle, action: restore)
                Button("Delete…", systemImage: "trash", action: delete)
                    .labelStyle(.iconOnly)
                    .help("Delete…")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .opacity(isFocused ? 1 : 0)
        }
        .foregroundStyle(isFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: AppMetrics.rowHighlightRadius, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(.rect)
        .contextMenu {
            Button("Load", action: load)
            Button(restoreTitle, action: restore)
            Divider()
            Button("Delete…", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: [entry.slotTitle, entry.name].compactMap { $0 }.joined(separator: ", ")))
    }

    private var restoreTitle: LocalizedStringKey {
        entry.slot == 0 ? "Restore as Quick Save" : "Restore to Slot \(entry.slot)"
    }
}

// MARK: - Achievements

/// One achievement: badge, title, description, progress and points.
struct AchievementRow: View {
    let achievement: AchievementInfo
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Group {
                if let url = achievement.imageURL.flatMap(URL.init(string:)) {
                    RemoteBadge(url: url, size: 40)
                } else {
                    Image(systemName: "trophy").frame(width: 40, height: 40)
                }
            }
            .opacity(achievement.isUnlocked ? 1 : 0.6)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(achievement.title)
                    .font(.body.weight(.semibold))
                Text(achievement.detail)
                    .font(.subheadline)
                    .foregroundStyle(isFocused ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
                if !achievement.isUnlocked, !achievement.progress.isEmpty {
                    HStack(spacing: AppSpacing.s) {
                        ProgressView(value: Double(achievement.progressFraction))
                            .frame(maxWidth: 160)
                        Text(achievement.progress)
                            .font(.caption.monospacedDigit())
                    }
                }
                if let date = achievement.unlockDate {
                    Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(isFocused ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                } else if achievement.isUnsupported {
                    Text("Not supported by this version of Atrium")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: AppSpacing.s)
            Text("\(achievement.points) pts")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isFocused ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(isFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: AppMetrics.rowHighlightRadius, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(achievement.isUnlocked ? Text("Unlocked") : Text("Locked"))
    }
}
