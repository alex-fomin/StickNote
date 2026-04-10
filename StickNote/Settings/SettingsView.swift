import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

private enum SettingsWindowMetrics {
    static let width: CGFloat = 400
    /// Fixed height: fits General (shortcuts) and Note tabs without excess empty space.
    static let height: CGFloat = 450
}

struct SettingsView: View {
    @State private var isThirdPartyNoticesPresented = false

    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.trimAfterPaste) var trimAfterPaste
    @Default(.showOnAllSpaces) var showOnAllSpaces
    @Default(.deleteToTrashBin) var deleteToTrashBin
    @Default(.maximizeOnHover) var maximizeOnHover
    @Default(.maximizeOnEdit) var maximizeOnEdit
    @Default(.showNotesCount) var showNotesCount

    @Environment(\.modelContext) var modelContext
    @Query var layouts: [NoteLayout]

    @State private var defaultLayout: NoteLayout? = NoteLayout.defaultLayouts().first!

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
                    LaunchAtLogin.Toggle()
                    Toggle("Show notes count in menubar", isOn: $showNotesCount)
                    
                    Section("Shortcuts") {
                        KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                        KeyboardShortcuts.Recorder(
                            "Paste note from clipboard", name: .createNoteFromClipboard)
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
                                Link("github.com/alex-fomin/StickNote", destination: URL(string: "https://github.com/alex-fomin/StickNote")!)
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
                        Button("Third-party licenses…") {
                            isThirdPartyNoticesPresented = true
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
