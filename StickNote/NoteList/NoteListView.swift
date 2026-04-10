import Defaults
import SwiftData
import SwiftUI
import Textual

enum SelectedFolder {
    case Notes
    case TrashBin
    case Hidden
}

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppStateModel.self) private var appStateModel

    @Query(filter: #Predicate<Note> { $0.isInTrashBin == false && $0.isHidden == false }) private var notes: [Note]
    @Query(filter: #Predicate<Note> { $0.isInTrashBin == true }) private var deleted: [Note]
    @Query(filter: #Predicate<Note> { $0.isInTrashBin == false && $0.isHidden == true }) private var hiddenNotes: [Note]
    @State private var showEmptyTrashConfirmation = false

    @State private var lastHandledRevealHiddenToken: Int = 0
    @State private var selectedFolder: SelectedFolder?
    @State private var selectedNote: Note?
    @State private var searchText: String = ""

    @State private var sortOrder = [KeyPathComparator(\Note.updatedAt, order: .reverse)]

    @State private var selectedNoteId: Note.ID?

    @State private var showConfirmation = false
    @State private var hideUntilSheetNote: Note?
    @Default(.confirmOnDelete) var confirmOnDelete

    @Query var layouts: [NoteLayout]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    fileprivate func DateTableColumn(_ titleKey: LocalizedStringKey, value: KeyPath<Note, Date>)
        -> TableColumn<
            Note, KeyPathComparator<Note>, some View, Text
        >
    {
        return TableColumn(titleKey, value: value) { n in
            VStack(alignment: .leading) {
                let date: Date = n[keyPath: value]

                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .controlSize(.small)
                Text(date.formatted(date: .omitted, time: .standard))
                    .controlSize(.small)
            }
        }
        .width(min: 50, ideal: 70, max: 70)
    }

    fileprivate func RestoreButton(note: Note) -> Button<Label<Text, Image>> {
        return Button("Restore", systemImage: "arrow.up.trash") {
            note.isInTrashBin = false
            note.isHidden = false
            note.hiddenUntil = nil
            note.updatedAt = Date.now
            AppState.shared.openNote(note, isEditing: false)
            self.selectedFolder = .Notes
            self.selectedNote = note
        }
    }

    fileprivate func UnhideButton(note: Note) -> Button<Label<Text, Image>> {
        Button("Unhide", systemImage: "eye") {
            AppState.shared.unhideNote(note)
            self.selectedFolder = .Notes
            self.selectedNote = note
        }
    }

    fileprivate func HideButton(note: Note) -> some View {
        Button("Hide", systemImage: "eye.slash") {
            AppState.shared.hideNote(note)
            self.selectedNote = nil
        }
    }

    fileprivate func HideUntilButton(note: Note) -> some View {
        Button("Hide note until…", systemImage: "calendar.badge.clock") {
            hideUntilSheetNote = note
        }
    }

    fileprivate func MarkdownToggle(note: Note) -> some View {
        Toggle(isOn: Binding(
            get: { note.isMarkdown },
            set: { newValue in
                note.isMarkdown = newValue
                note.markdownAutoDisabledByUser = !newValue
            }
        )) {
            Label("Markdown", systemImage: "doc.richtext")
        }
    }

    fileprivate func ExportToFileButton(note: Note) -> some View {
        Button("Export to file…", systemImage: "square.and.arrow.down") {
            AppState.shared.exportNoteToFile(note)
        }
    }

    fileprivate func DeleteButton(note: Note) -> some View {
        return Button("Delete", systemImage: "trash") {
            if confirmOnDelete {
                showConfirmation = true
            } else {
                AppState.shared.deleteNote(note)
                self.selectedNote = nil
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(note.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            Button {
                AppState.shared.deleteNote(note)
                self.selectedNote = nil
            } label: {
                Text("Delete")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFolder) {
                NavigationLink(value: SelectedFolder.Notes) {
                    Label("Notes", systemImage: "note.text")
                        .badge(filteredNotes(notes: getNoteList(.Notes)).count)
                }
                NavigationLink(value: SelectedFolder.Hidden) {
                    Label("Hidden", systemImage: "eye.slash")
                        .badge(filteredNotes(notes: getNoteList(.Hidden)).count)
                }
                NavigationLink(value: SelectedFolder.TrashBin) {
                    Label("Trash", systemImage: "trash")
                        .badge(filteredNotes(notes: getNoteList(.TrashBin)).count)
                }
            }
            .onAppear {
                if !syncRevealHiddenFolderSelection() {
                    if selectedFolder == nil {
                        selectedFolder = .Notes
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stickNoteRevealHiddenNotesInList)) {
                _ in
                lastHandledRevealHiddenToken = appStateModel.noteListRevealHiddenToken
                selectedFolder = .Hidden
            }
            .onChange(of: selectedFolder) {
                selectedNote = nil
            }
            .navigationTitle("Select list")
            .searchable(text: $searchText)
            .onChange(of: searchText) {
                let noteList = filteredNotes(notes: getNoteList(selectedFolder!))

                if let note = selectedNote {
                    if !noteList.contains(note) {
                        selectedNote = nil
                    }
                } else {
                    if !noteList.isEmpty {
                        selectedNote = noteList.first!
                    }
                }
            }
        } content: {
            if let selectedFolder {
                Table(of: Note.self, selection: $selectedNoteId, sortOrder: $sortOrder) {
                    TableColumn("Text", value: \.text)
                    DateTableColumn("Created", value: \.createdAt)
                    DateTableColumn(
                        selectedFolder == .TrashBin ? "Deleted" : "Updated", value: \.updatedAt)
                    TableColumn("Maximized") { n in
                        Toggle(
                            "",
                            isOn: Binding<Bool>(
                                get: { !n.isMinimized },
                                set: { n.isMinimized = !$0 }))
                    }
                    .width(50)
                    .alignment(.center)
                    .defaultVisibility(
                        selectedFolder == .Notes || selectedFolder == .Hidden ? .visible : .hidden)

                    TableColumn("All spaces") { n in
                        Toggle(
                            "",
                            isOn: Binding<Bool>(
                                get: { n.showOnAllSpaces },
                                set: { n.showOnAllSpaces = $0 }))
                    }
                    .width(50)
                    .alignment(.center)
                    .defaultVisibility(
                        selectedFolder == .Notes || selectedFolder == .Hidden ? .visible : .hidden)

                    TableColumn("Layout") { (n: Note) in
                        LayoutPickerView(
                            "",
                            selectedLayout: Binding<NoteLayout?>(
                                get: { layouts.first(where: { $0.isSameAppearance(n) }) },
                                set: { layout in
                                    if let layout {
                                        n.apply(layout: layout)
                                    }
                                }
                            ), layouts: layouts)
                    }
                    .width(100)
                    .defaultVisibility(
                        selectedFolder == .Notes || selectedFolder == .Hidden ? .visible : .hidden)

                    TableColumn("Hide until") { n in
                        if let u = n.hiddenUntil {
                            VStack(alignment: .leading) {
                                Text(u.formatted(date: .abbreviated, time: .omitted))
                                    .controlSize(.small)
                                Text(u.formatted(date: .omitted, time: .shortened))
                                    .controlSize(.small)
                            }
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                                .controlSize(.small)
                        }
                    }
                    .width(min: 80, ideal: 100, max: 120)
                    .defaultVisibility(selectedFolder == .Hidden ? .visible : .hidden)

                } rows: {
                    ForEach(filteredNotes(notes: getNoteList(selectedFolder))) { note in
                        TableRow(note)
                            .contextMenu {
                                if note.isInTrashBin {
                                    RestoreButton(note: note)
                                    MarkdownToggle(note: note)
                                    ExportToFileButton(note: note)
                                    DeleteButton(note: note)
                                } else if note.isHidden {
                                    UnhideButton(note: note)
                                    MarkdownToggle(note: note)
                                    ExportToFileButton(note: note)
                                    DeleteButton(note: note)
                                } else {
                                    HideButton(note: note)
                                    HideUntilButton(note: note)
                                    MarkdownToggle(note: note)
                                    ExportToFileButton(note: note)
                                    DeleteButton(note: note)
                                }
                            }
                    }
                }
                .onChange(of: selectedNoteId) {
                    if let noteId = selectedNoteId {
                        selectedNote = getNoteList(selectedFolder).first(where: { $0.id == noteId })
                    }
                }

            } else {
                Text("Select note list")
            }
        } detail: {
            if let note = selectedNote {
                if note.isMarkdown {
                    NoteListMarkdownPreview(note: note)
                } else if note.isInTrashBin {
                    TextEditor(text: .constant(note.text))
                        .modifier(NoteModifier(note: note))
                } else {
                    TextEditor(
                        text: Binding<String>(
                            get: { note.text },
                            set: { note.text = $0 })
                    )
                    .modifier(NoteModifier(note: note))
                }
            }
        }
        .toolbar {
            if let selectedFolder {
                if selectedFolder == .TrashBin {
                    ToolbarItem(placement: .navigation) {
                        Button("Empty") {
                            showEmptyTrashConfirmation = true
                        }
                        .disabled(getNoteList(selectedFolder).isEmpty)
                        .confirmationDialog(
                            "Are you sure you want to permanently erase the notes in the Trash?",
                            isPresented: $showEmptyTrashConfirmation
                        ) {
                            Button("Empty Trash") {
                                AppState.shared.emptyTrashBin()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You can’t undo this action.")
                        }
                    }
                }

                if let note = selectedNote {
                    if selectedFolder == .TrashBin {
                        ToolbarItem {
                            RestoreButton(note: note)
                        }
                    } else if selectedFolder == .Hidden {
                        ToolbarItem {
                            UnhideButton(note: note)
                        }
                        ToolbarItem {
                            DeleteButton(note: note)
                        }
                    } else {
                        ToolbarItem {
                            HideButton(note: note)
                        }
                        ToolbarItem {
                            HideUntilButton(note: note)
                        }
                        ToolbarItem {
                            DeleteButton(note: note)
                        }
                    }
                }
            }
        }
        .sheet(item: $hideUntilSheetNote) { note in
            HideNoteUntilSheet(note: note) {
                selectedNote = nil
                selectedNoteId = nil
            }
        }
    }

    func filteredNotes(notes: [Note]) -> [Note] {
        if searchText == "" {
            return notes
        } else {
            return notes.filter { $0.text.contains(searchText) }
        }
    }

    func getNoteList(_ selectedFolder: SelectedFolder) -> [Note] {
        var resultNotes: [Note] = []

        switch selectedFolder {
        case .Notes:
            resultNotes = notes
        case .Hidden:
            resultNotes = hiddenNotes
        case .TrashBin:
            resultNotes = deleted
        }

        resultNotes.sort(using: sortOrder)
        return resultNotes
    }

    @discardableResult
    private func syncRevealHiddenFolderSelection() -> Bool {
        let token = appStateModel.noteListRevealHiddenToken
        guard token > lastHandledRevealHiddenToken else { return false }
        lastHandledRevealHiddenToken = token
        selectedFolder = .Hidden
        return true
    }
}

/// Read-only rendered Markdown for the note list detail pane (same styling as the note window).
private struct NoteListMarkdownPreview: View {
    let note: Note

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            StructuredText(note.text, parser: StickNoteMarkdownParser())
                .textual.textSelection(.enabled)
                .textual.structuredTextStyle(StickNoteStructuredTextStyle())
                .font(Font(note.nsFont))
                .foregroundStyle(Color.fromString(note.fontColor))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.fromString(note.color))
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)

    let note = Note(layout: NoteLayout.defaultLayout, text: "This is note\nMultiline")
    container.mainContext.insert(note)
    let deletedNote = Note(layout: NoteLayout.defaultLayout, text: "DeletedNote")
    deletedNote.isInTrashBin = true
    container.mainContext.insert(deletedNote)

    let hiddenNote = Note(layout: NoteLayout.defaultLayout, text: "Hidden note")
    hiddenNote.isHidden = true
    container.mainContext.insert(hiddenNote)

    let scheduledHidden = Note(layout: NoteLayout.defaultLayout, text: "Scheduled hidden")
    scheduledHidden.isHidden = true
    scheduledHidden.hiddenUntil = Date.now.addingTimeInterval(86_400)
    container.mainContext.insert(scheduledHidden)

    return NoteListView()
        .environment(AppStateModel())
        .frame(width: 2000, height: 2000)
        .modelContainer(container)
}
