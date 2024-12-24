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

    @Environment(\.modelContext) var modelContext
    @Query var layouts: [NoteLayout]

    @State private var defaultLayout: NoteLayout = NoteLayout.defaultLayouts().first!

    var body: some View {
        HStack {
            Form {
                Section("Shortcuts") {
                    KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                    KeyboardShortcuts.Recorder(
                        "Paste note from clipboard", name: .createNoteFromClipboard)
                    KeyboardShortcuts.Recorder(
                        "Show/Hide notes", name: .showHideNotes)
                }
                Section("New note") {
                    Toggle("Show on all spaces", isOn: $showOnAllSpaces)
                    Picker("Default layout", selection: $defaultLayout) {
                        ForEach(layouts) { layout in
                            let nsFont = NSFont(layout).withSize(NSFont.systemFontSize)
                            
                            return HStack{
                                Image(
                                    systemName: "square.fill"
                                )
                                .foregroundStyle(
                                    Color.fromString(layout.color),
                                    Color.fromString(layout.color))
                                
                                Text(layout.name)
                                    .font(Font(nsFont))

                            }.tag(layout)
                        }
                    }
                    .onAppear {
                        defaultLayout = layouts.first { $0.isDefault }!
                    }
                    .onChange(of: defaultLayout) { old, new in
                        try? self.modelContext.transaction {
                            old.isDefault = false
                            new.isDefault = true
                        }
                    }

                }
                Section {
                    LaunchAtLogin.Toggle()
                    Toggle("Confirm on delete", isOn: $confirmOnDelete)
                    Toggle("Delete to trash bin", isOn: $deleteToTrashBin)
                }
            }

            .padding(20)
            .formStyle(.grouped)
        }
    }
}

#Preview {
    SettingsView()
}
