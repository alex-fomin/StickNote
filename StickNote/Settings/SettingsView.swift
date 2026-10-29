import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

enum SettingsWindowMetrics {
    static let width: CGFloat = 400
    /// Fixed height: fits General (shortcuts) and Note tabs without excess empty space.
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

    @State private var defaultLayout: NoteLayout? = NoteLayout.defaultLayouts().first!

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
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
                    Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    Text(
                        "With the menu bar icon hidden, open Settings from a note’s StickNote menu, start StickNote again (for example from Finder or Launchpad) to show this window, or use the keyboard shortcuts below."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    Toggle("Show notes count in menubar", isOn: $showNotesCount)
                        .disabled(!showMenuBarIcon)
                    Toggle("Hide notes when a fullscreen app is active", isOn: $hideNotesWhenFullscreenApp)
                    Text(
                        "Floating notes are hidden while another app is using native fullscreen. Use Show/Hide notes or the menu bar icon to bring them back temporarily."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Section("Shortcuts") {
                        KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                        KeyboardShortcuts.Recorder(
                            "Paste note from clipboard", name: .createNoteFromClipboard)
                        KeyboardShortcuts.Recorder(
                            "Append clipboard to inbox / latest note",
                            name: .appendClipboardToLatestNote)
                        KeyboardShortcuts.Recorder(
                            "Show/Hide notes", name: .showHideNotes)
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
                            defaultLayout = layouts.first { $0.isDefault }!
                        }
                        .onChange(of: defaultLayout!) { old, new in
                            try? self.modelContext.transaction {
                                old.isDefault = false
                                new.isDefault = true
                            }
                        }

                    }
                    Section("Paste note") {
                        Toggle("Trim whitespaces", isOn: $trimAfterPaste)
                        Toggle("Wrap long lines", isOn: $wrapLongLinesAfterPaste)
                    }
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
