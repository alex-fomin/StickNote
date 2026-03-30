import SwiftData
import SwiftUI

enum HideNoteUntilDefaults {
    /// Tomorrow at 9:00 in the current calendar (used as the initial picker value).
    static func suggestedDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    static func initialPickerDate() -> Date {
        let s = suggestedDate()
        return s > Date.now ? s : (Calendar.current.date(byAdding: .minute, value: 1, to: Date.now) ?? s)
    }
}

struct HideNoteUntilSheet: View {
    @Environment(\.dismiss) private var dismiss

    let note: Note
    private let onDidScheduleHide: (() -> Void)?
    @State private var chosenDate: Date

    init(note: Note, onDidScheduleHide: (() -> Void)? = nil) {
        self.note = note
        self.onDidScheduleHide = onDidScheduleHide
        _chosenDate = State(initialValue: HideNoteUntilDefaults.initialPickerDate())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The note stays hidden until the date and time you choose.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DatePicker(
                "Hide until",
                selection: $chosenDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Hide note") {
                    AppState.shared.hideNote(note, hiddenUntil: chosenDate)
                    onDidScheduleHide?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosenDate <= Date.now)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
