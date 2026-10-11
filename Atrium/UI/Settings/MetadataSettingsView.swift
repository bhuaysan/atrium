// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

struct MetadataSettingsView: View {
    @Environment(MetadataService.self) private var metadata
    @Environment(\.modelContext) private var context
    @Query private var games: [Game]

    @AppStorage(PrefKey.scraperUsername) private var username = ""
    @AppStorage(PrefKey.scraperLanguage) private var language = "en"
    @AppStorage(PrefKey.scraperRegion) private var region = "eu"
    @AppStorage(PrefKey.autoScrape) private var autoScrape = true
    @State private var password = ""
    @State private var account = AccountStatus.unchecked

    private enum AccountStatus: Equatable {
        case unchecked, checking
        case valid(ScraperAccount)
        case failed(String)
    }

    private let languages = [("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español"), ("it", "Italiano"), ("pt", "Português")]
    private let regions = [("eu", String(localized: "Europe")), ("us", String(localized: "North America")), ("jp", String(localized: "Japan")), ("wor", String(localized: "World"))]

    var body: some View {
        Form {
            Section {
                if !Secrets.hasScreenScraperCredentials {
                    StatusLabel("This build has no ScreenScraper developer credentials. See the README for how to add them.",
                                kind: .warning, prominent: true)
                }
                TextField("Username", text: $username)
                    .textContentType(.username)
                SecureField(text: $password) {
                    Text("Password")
                    Text("Stored in your keychain.")
                }
                .textContentType(.password)
                .onSubmit { Keychain.setPassword(password, for: username) }
                .onChange(of: password) { _, value in
                    Keychain.setPassword(value, for: username)
                    account = .unchecked
                }
                HStack(alignment: .firstTextBaseline) {
                    accountStatus
                    Spacer(minLength: AppSpacing.s)
                    Button("Check Account", action: checkAccount)
                        .disabled(username.isEmpty || password.isEmpty || account == .checking)
                }
            } header: {
                Text("ScreenScraper Account")
            } footer: {
                Text("Optional. A free account at screenscraper.fr raises the daily request quota and speeds up scraping.")
                    .settingsFootnote()
            }

            Section("Preferences") {
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Preferred Region", selection: $region) {
                    ForEach(regions, id: \.0) { Text($0.1).tag($0.0) }
                }
                Toggle(isOn: $autoScrape) {
                    Text("Fetch Metadata Automatically")
                    Text("New games get box art, descriptions and ratings as soon as a scan finds them.")
                }
            }

            Section("Library") {
                if metadata.isPausedForQuota, !metadata.isRunning {
                    StatusLabel("Daily ScreenScraper quota reached", kind: .warning, prominent: true,
                                detail: String(localized: "Fetching continues automatically tomorrow. Fetch Missing tries again now."))
                }
                if let failure = metadata.lastError {
                    HStack(alignment: .firstTextBaseline) {
                        StatusLabel("Metadata couldn't be fetched", kind: .error, prominent: true, detail: failure.message)
                        Spacer(minLength: AppSpacing.s)
                        Button("Retry") { metadata.enqueue(games, context: context) }
                            .buttonStyle(.link)
                    }
                }
                LabeledContent("Matched") {
                    Text("\(games.filter { $0.scrapeState == .matched }.count) of \(games.count)")
                        .monospacedDigit()
                }
                if metadata.isRunning {
                    LabeledContent("Fetching Metadata") {
                        HStack(spacing: AppSpacing.s) {
                            ProgressView(value: metadata.progress)
                                .frame(width: 120)
                            Button("Stop") { metadata.cancel() }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Refetch All") { metadata.enqueue(games, force: true, context: context) }
                    Button("Fetch Missing") { metadata.enqueue(games, context: context) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { password = Keychain.password(for: username) ?? "" }
        .onChange(of: username) { _, value in
            password = Keychain.password(for: value) ?? ""
            account = .unchecked
        }
    }

    @ViewBuilder
    private var accountStatus: some View {
        switch account {
        case .unchecked:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
        case .valid(let info):
            if let used = info.requestsToday, let limit = info.maxRequestsPerDay {
                StatusLabel("Signed in", kind: .success,
                            detail: String(localized: "\(used) of \(limit) requests used today"))
            } else {
                StatusLabel("Signed in", kind: .success)
            }
        case .failed(let message):
            StatusLabel("Account couldn't be checked", kind: .error, detail: message)
        }
    }

    private func checkAccount() {
        Keychain.setPassword(password, for: username)
        account = .checking
        Task {
            do {
                account = .valid(try await metadata.checkAccount())
            } catch {
                account = .failed(MetadataFailure(error).message)
            }
        }
    }
}
