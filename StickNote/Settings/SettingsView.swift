import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

enum SettingsTab {
    case Settings
    case Layouts
    case About
}

struct SettingsView: View {
    @Default(.confirmOnDelete) var confirmOnDelete
    @Default(.showOnAllSpaces) var showOnAllSpaces
    @Default(.deleteToTrashBin) var deleteToTrashBin
    @Default(.maximizeOnHover) var maximizeOnHover
    @Default(.maximizeOnEdit) var maximizeOnEdit

    @Environment(\.modelContext) var modelContext
    @Query var layouts: [NoteLayout]

    @State private var defaultLayout: NoteLayout? = NoteLayout.defaultLayouts().first!

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
                    LaunchAtLogin.Toggle()
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
                            "Default layout", selectedLayout: $defaultLayout,
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
                }
                .formStyle(.grouped)
            }
        }
        .scenePadding()
        .frame(maxWidth: 400, minHeight: 100)
    }
}
#Preview {
    SettingsView()
}


