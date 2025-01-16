import SwiftData
import SwiftUI
import Defaults

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
    
    @State private var showConfirmation = false
    @Default(.confirmOnDelete) var confirmOnDelete

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
                let noteList = filteredNotes(notes: getNoteList(selectedFolder))
                List(selection: $selectedNote) {
                    if selectedFolder == .TrashBin {
                        HStack {
                            Spacer()
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
                            .controlSize(.small)
                        }
                        .listRowInsets(
                            .init(
                                top: 1,
                                leading: 0,
                                bottom: 10,
                                trailing: 0))
                    }
                    ForEach(noteList, id: \.id) { item in
                        NavigationLink(value: item) {
                            Text(item.text.truncate(50, maxLines: 2))
                        }
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
                    NoteInfoView(note: note)
                }
            }
        }
        .toolbar {
            if let selectedFolder {
                ToolbarItemGroup(placement: .secondaryAction) {
                    if let note = selectedNote {
                        if selectedFolder == .TrashBin {
                            Button("Restore", systemImage: "arrow.up.trash") {
                                note.isInTrashBin = false
                                AppState.shared.openNote(note, isEditing: false)
                                self.selectedFolder = .Notes
                                self.selectedNote = note
                            }
                        } else {
                            Button("Delete", systemImage: "trash") {
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
        switch selectedFolder {
        case .Notes:
            return notes
        case .TrashBin:
            return deleted
        }
    }
}

struct NoteInfoView: View {
    @Environment(\.modelContext) var modelContext
    @Query var layouts: [NoteLayout]

    @Bindable var note: Note
    @State var layout: NoteLayout? = nil

    var body: some View {
        VStack(alignment: .trailing) {
            TextEditor(text: $note.text)
                .modifier(NoteModifier(note: note))

            Form {
                Toggle("Show on all spaces", isOn: $note.showOnAllSpaces)
                    .onChange(of: $note.showOnAllSpaces.wrappedValue) {
                        _, newValue in
                        AppState.shared.applyShowOnAllSpaces(note: note)
                    }
                Toggle("Maximized", isOn: !$note.isMinimized)
                    .onChange(of: $note.isMinimized.wrappedValue) {
                        _, newValue in
                        AppState.shared.applyShowOnAllSpaces(note: note)
                    }
                LayoutPickerView("Layout", selectedLayout: $layout, layouts: layouts)
                    .onAppear {
                        layout = layouts.first(where: { $0.isSameAppearance(note) })
                    }
            }
            .formStyle(.grouped)
            .onChange(of: layout) { _, newValue in
                if let newValue {
                    if !note.isSameAppearance(newValue) {
                        note.apply(layout: newValue)
                    }
                }
            }
        }
        .onChange(of: note) {
            layout = layouts.first(where: { $0.isSameAppearance(note) })
        }
        .padding()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)

    let note = Note(layout: NoteLayout.defaultLayout, text: "This is note")
    container.mainContext.insert(note)
    let deletedNote = Note(layout: NoteLayout.defaultLayout, text: "DeletedNote")
    deletedNote.isInTrashBin = true
    container.mainContext.insert(deletedNote)

    return NoteListView()
        .modelContainer(container)
}
