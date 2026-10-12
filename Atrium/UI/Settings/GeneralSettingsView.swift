// SPDX-License-Identifier: GPL-3.0-or-later

import AtriumCore
import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(BackupService.self) private var backup
    @Environment(\.modelContext) private var context
    @State private var selection: URL?
    @State private var folderToRemove: FolderRemoval?

    private struct FolderRemoval: Identifiable {
        var folder: URL
        var gameCount: Int
        var id: URL { folder }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 0) {
                    List(selection: $selection) {
                        ForEach(library.folders, id: \.self) { folder in
                            folderRow(folder)
                        }
                    }
                    .listStyle(.bordered)
                    .alternatingRowBackgrounds(.disabled)
                    .frame(minHeight: 140)
                    .onDeleteCommand(perform: confirmRemoval)
                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            library.presentAddFolderPanel(context: context)
                        } label: {
                            Label("Add Folder…", systemImage: "plus")
                        }
                        .help("Add Folder…")
                        Button(action: confirmRemoval) {
                            Label("Remove Folder…", systemImage: "minus")
                        }
                        .help("Remove Folder…")
                        .disabled(selection == nil)
                    }
                    .buttonStyle(ListEditButtonStyle())
                    .padding(.top, AppSpacing.s)
                }
                HStack(spacing: AppSpacing.s) {
                    Spacer()
                    if library.isScanning { ProgressView().controlSize(.small) }
                    Button("Rescan") { Task { await library.rescan(context: context) } }
                        .disabled(library.isScanning || library.folders.isEmpty)
                }
            } header: {
                Text("Library Folders")
            } footer: {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if let summary = library.lastScanSummary {
                        Text(summary)
                    }
                    Text("Name sub folders after the system (for example “PSX”, “Saturn” or “Arcade”) so disc images and archives are assigned correctly.")
                }
                .settingsFootnote()
            }

            Section {
                LabeledContent("Backup") {
                    HStack(spacing: AppSpacing.s) {
                        if let activity = backup.activity {
                            ProgressView().controlSize(.small)
                            Text(activity).foregroundStyle(.secondary)
                        }
                        Button("Back Up…") { backup.backUp() }
                        Button("Restore…") { backup.restore() }
                    }
                    .disabled(backup.isWorking)
                }
                LabeledContent("Application Data") {
                    Button("Show in Finder") { NSWorkspace.shared.open(AppPaths.root) }
                }
                LabeledContent("Battery Saves") {
                    Button("Show in Finder") { NSWorkspace.shared.open(AppPaths.saves) }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("A backup contains your library, battery saves, save states, artwork, screenshots, manuals, patches, cheats and settings. BIOS files, cores and your passwords are not included.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            Text("Remove “\(folderToRemove?.folder.lastPathComponent ?? "")” from the library?"),
            isPresented: $folderToRemove.isPresent(),
            presenting: folderToRemove
        ) { removal in
            Button("Remove Folder", role: .destructive) {
                library.removeFolder(removal.folder, context: context)
                selection = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { removal in
            Text("\(removal.gameCount) games will be removed from the library. The files stay on disk.")
        }
    }

    private func folderRow(_ folder: URL) -> some View {
        let isUnreachable = library.unreachableFolders.contains(folder)
        return Label {
            VStack(alignment: .leading) {
                Text(folder.lastPathComponent)
                Text(folder.path(percentEncoded: false))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            if isUnreachable {
                Image(systemName: "externaldrive.badge.exclamationmark").foregroundStyle(.orange)
            } else {
                Image(systemName: "folder.fill").foregroundStyle(.tint)
            }
        }
        .help(isUnreachable ? String(localized: "Unavailable. Connect the drive, then rescan.") : "")
        .accessibilityValue(isUnreachable ? String(localized: "Unavailable") : "")
        .tag(folder)
    }

    private func confirmRemoval() {
        guard let selection else { return }
        folderToRemove = FolderRemoval(folder: selection,
                                       gameCount: library.games(leavingWith: selection, context: context).count)
    }
}

/// The square +/− buttons under an editable list, as in System Settings.
private struct ListEditButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .frame(width: 22, height: 22)
            .background(configuration.isPressed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary),
                        in: .rect(cornerRadius: 5))
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .contentShape(.rect)
    }
}
