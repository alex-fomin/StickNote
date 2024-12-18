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

    var body: some View {
        HStack {
            Form {
                Section("Shortcuts") {
                    KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                    KeyboardShortcuts.Recorder(
                        "Paste note from clipboard", name: .createNoteFromClipboard)
                }
                Section {
                    LaunchAtLogin.Toggle()
                    Toggle("Confirm on delete", isOn: $confirmOnDelete)
                    
                }
                Button("Reset all") {
                    try? AppState.shared.sharedModelContainer.erase()
                }
                
                //                Se
            }
            
            .padding(20)
            .formStyle(.grouped)
        }
    }
}

#Preview {
    SettingsView()
}
