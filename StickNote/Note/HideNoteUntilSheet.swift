import SwiftData
import SwiftUI

private enum HideNoteUntilDefaults {
    /// Next 9:00 AM local: today if still ahead, otherwise tomorrow.
    static func nextNineAM() -> Date {
        let cal = Calendar.current
        let now = Date.now
        var parts = cal.dateComponents([.year, .month, .day], from: now)
        parts.hour = 9
        parts.minute = 0
        parts.second = 0
        let todayNineAM = cal.date(from: parts) ?? now
        if todayNineAM > now { return todayNineAM }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    static func initialPickerDate() -> Date {
        nextNineAM()
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

    private var isValid: Bool {
        chosenDate > Date.now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hide until later")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "",
                    selection: $chosenDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .accessibilityLabel("Date")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "",
                    selection: $chosenDate,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .accessibilityLabel("Time")
            }

            HStack(spacing: 12) {
                Spacer(minLength: 0)
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
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(maxWidth: 320, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
}
