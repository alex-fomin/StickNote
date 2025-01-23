import Defaults
import SwiftData
import SwiftUI

enum SelectedFolder {
    case Notes
    case TrashBin
}

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isInTrashBin == false }) private var notes: [Note]
    @Query(filter: #Predicate<Note> { $0.isInTrashBin == true }) private var deleted: [Note]
    @State private var showEmptyTrashConfirmation = false

    @State private var selectedFolder: SelectedFolder?
    @State private var selectedNote: Note?
    @State private var searchText: String = ""

    @State private var sortOrder = [KeyPathComparator(\Note.text)]

    @State private var selectedNoteId: Note.ID?

    @State private var showConfirmation = false
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
            note.updatedAt = Date.now
            AppState.shared.openNote(note, isEditing: false)
            self.selectedFolder = .Notes
            self.selectedNote = note
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
                NavigationLink(value: SelectedFolder.TrashBin) {
                    Label("Trash", systemImage: "trash")
                        .badge(filteredNotes(notes: getNoteList(.TrashBin)).count)
                }
            }
            .onAppear {
                selectedFolder = .Notes
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
                        selectedFolder == .Notes ? "Updated" : "Deleted", value: \.updatedAt)
                    TableColumn("Maximized") { n in
                        Toggle(
                            "",
                            isOn: Binding<Bool>(
                                get: { !n.isMinimized },
                                set: { n.isMinimized = !$0 }))
                    }
                    .width(50)
                    .alignment(.center)
                    .defaultVisibility(selectedFolder == .Notes ? .visible : .hidden)

                    TableColumn("All spaces") { n in
                        Toggle(
                            "",
                            isOn: Binding<Bool>(
                                get: { n.showOnAllSpaces },
                                set: { n.showOnAllSpaces = $0 }))
                    }
                    .width(50)
                    .alignment(.center)
                    .defaultVisibility(selectedFolder == .Notes ? .visible : .hidden)

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
                    .defaultVisibility(selectedFolder == .Notes ? .visible : .hidden)

                } rows: {
                    ForEach(filteredNotes(notes: getNoteList(selectedFolder))) { note in
                        TableRow(note)
                            .contextMenu {
                                if note.isInTrashBin {
                                    RestoreButton(note: note)
                                } else {
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
                if note.isInTrashBin {
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
                    ToolbarItem {
                        if selectedFolder == .TrashBin {
                            RestoreButton(note: note)
                        } else {
                            DeleteButton(note: note)
                        }
                    }
                }
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
        case .TrashBin:
            resultNotes = deleted
        }

        resultNotes.sort(using: sortOrder)
        return resultNotes
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

    return NoteListView()
        .frame(width: 2000, height: 2000)
        .modelContainer(container)
}
