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

    @State private var selectedFolder: SelectedFolder?
    @State private var selectedNote: Note?
    @State private var searchText: String = ""

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
                    ForEach(noteList, id: \.self) { item in
                        NavigationLink(value: item) {
                            Text(item.text)
                        }
                    }
                }
            } else {
                Text("Select note list")
            }
        } detail: {
            if let note = selectedNote {
                if note.isInTrashBin {
                    VStack {
                        NoteTextView(note: note, allowSelection: true)
                    }
                    Button("Restore") {
                        note.isInTrashBin = false
                        selectedNote = note
                        selectedFolder = .Notes
                    }
                } else {
                    NoteInfoView(note: note)
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
    @Bindable var note: Note
    var body: some View {
        VStack {
            NoteTextView(note: note)
            Toggle("Show on all spaces", isOn: $note.showOnAllSpaces)
                .onChange(of: $note.showOnAllSpaces.wrappedValue) {
                    _, newValue in
                    AppState.shared.applyShowOnAllSpaces(note: note)
                }
        }
    }
}

#Preview {
    NoteListView()
        .modelContainer(for: Note.self, inMemory: true)
}
