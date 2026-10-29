import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

enum SettingsWindowMetrics {
    static let width: CGFloat = 460
    /// Fixed height: fits the Note tab without excess empty space.
    static let height: CGFloat = 560
}

struct SettingsView: View {
    @State private var isThirdPartyNoticesPresented = false

    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.trimAfterPaste) var trimAfterPaste
    @Default(.wrapLongLinesAfterPaste) var wrapLongLinesAfterPaste
    @Default(.showOnAllSpaces) var showOnAllSpaces
    @Default(.deleteToTrashBin) var deleteToTrashBin
    @Default(.maximizeOnHover) var maximizeOnHover
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.showNotesCount) var showNotesCount
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.hideNotesWhenFullscreenApp) var hideNotesWhenFullscreenApp
    @Default(.appAppearance) var appAppearanceRaw

    @Environment(\.modelContext) var modelContext
    @Query var layouts: [NoteLayout]

    @State private var defaultLayout: NoteLayout?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
                    Section("General") {
                        LaunchAtLogin.Toggle()
                        Picker(
                            "Appearance",
                            selection: Binding(
                                get: { AppAppearancePreference(rawValue: appAppearanceRaw) ?? .system },
                                set: { newValue in
                                    appAppearanceRaw = newValue.rawValue
                                    AppAppearance.applyFromDefaults()
                                }
                            )
                        ) {
                            ForEach(AppAppearancePreference.allCases) { pref in
                                Text(pref.title).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section {
                        Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                        Toggle("Show notes count in menu bar", isOn: $showNotesCount)
                            .disabled(!showMenuBarIcon)
                    } header: {
                        Text("Menu bar")
                    } footer: {
                        Self.footer(
                            "With the icon hidden, open Settings from a note’s StickNote menu, launch StickNote again, or use the keyboard shortcuts."
                        )
                    }
                    Section {
                        Toggle("Hide notes when a fullscreen app is active", isOn: $hideNotesWhenFullscreenApp)
                    } header: {
                        Text("Fullscreen")
                    } footer: {
                        Self.footer(
                            "Use Show/Hide notes or the menu bar icon to bring them back temporarily."
                        )
                    }
                }
                .formStyle(.grouped)
            }
            Tab("Note", systemImage: "note.text") {
                Form {
                    Section {
                        Toggle("Confirm on delete", isOn: $confirmOnDelete)
                        Toggle("Delete to trash bin", isOn: $deleteToTrashBin)
                        Toggle("Maximize on hover", isOn: $maximizeOnHover)
                        Toggle("Maximize after edit", isOn: $maximizeOnEdit)
                    }
                    Section("New note") {
                        Toggle("Show on all spaces", isOn: $showOnAllSpaces)
                        LayoutPickerView(
                            "Layout", selectedLayout: $defaultLayout,
                            layouts: layouts
                        )
                        .onAppear {
                            defaultLayout = layouts.first { $0.isDefault }
                        }
                        .onChange(of: defaultLayout) { old, new in
                            guard let new, old != new else { return }
                            try? self.modelContext.transaction {
                                old?.isDefault = false
                                new.isDefault = true
                            }
                        }
                    }
                    Section {
                        Toggle("Trim whitespaces", isOn: $trimAfterPaste)
                        Toggle("Wrap long lines", isOn: $wrapLongLinesAfterPaste)
                    } header: {
                        Text("Plain text paste")
                    } footer: {
                        Self.footer(
                            "Formatted text from web pages and documents is pasted as Markdown. Pasting goes to the Inbox note when one is set."
                        )
                    }
                }
                .formStyle(.grouped)
            }
            Tab("Shortcuts", systemImage: "keyboard") {
                Form {
                    KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                    KeyboardShortcuts.Recorder(
                        "Paste note from clipboard", name: .createNoteFromClipboard)
                    KeyboardShortcuts.Recorder(
                        "Show/Hide notes", name: .showHideNotes)
                }
                .formStyle(.grouped)
            }
            Tab("About", systemImage: "info.circle") {
                Form {
                    Section {
                        HStack(alignment: .center, spacing: 16) {
                            if let icon = NSApp.applicationIconImage {
                                Image(nsImage: icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 64, height: 64)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("StickNote")
                                    .font(.headline)
                                Text(
                                    "Version \(Self.appMarketingVersion) (\(Self.appBuildVersion))"
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                Link("alex-fomin.github.io/StickNote", destination: URL(string: "https://alex-fomin.github.io/StickNote/")!)
                                    .font(.subheadline)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                    if let copyright = Self.appCopyright, !copyright.isEmpty {
                        Section {
                            Text(copyright)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button("Check for Updates…") {
                            AppDelegate.checkForUpdates()
                        }
                        Button("Third-party licenses…") {
                            isThirdPartyNoticesPresented = true
                        }
                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .sheet(isPresented: $isThirdPartyNoticesPresented) {
            ThirdPartyNoticesView()
        }
        .scenePadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(
            minWidth: SettingsWindowMetrics.width,
            maxWidth: SettingsWindowMetrics.width,
            minHeight: SettingsWindowMetrics.height,
            maxHeight: SettingsWindowMetrics.height
        )
    }

    private static func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static var appMarketingVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    private static var appBuildVersion: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }

    private static var appCopyright: String? {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
    }
}
#Preview {
    SettingsView()
}
