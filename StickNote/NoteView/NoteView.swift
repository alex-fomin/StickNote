import SwiftUI

struct NoteView: View {
    init(item: Item, isEditing: Bool = false) {
        self.item = item
        self.isEditing = isEditing
        self.windowTracker = WindowPositionTracker(item: item)
        self.color = Color("Note" + item.color)
    }

    @Bindable var item: Item
    @State var nsWindow: NSWindow?

    @State private var isEditing: Bool

    @FocusState private var isTextEditorFocused: Bool  // Track focus on the TextEditor
    private let sharedFont: Font = .system(size: 18, weight: .regular, design: .monospaced)  // Shared font
    @State var color: Color

    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    private var windowTracker: WindowPositionTracker

    var body: some View {
        ZStack {
            if isEditing {
                TextEditor(text: $item.text, selection: $selection)
                    .focused($isTextEditorFocused)  // Bind focus state
                    .onAppear {
                        self.nsWindow?.styleMask.insert(.titled)
                        isTextEditorFocused = true  // Automatically focus
                        selection = TextSelection(
                            range: $item.text.wrappedValue
                                .startIndex..<$item.text.wrappedValue.endIndex)

                        self.nsWindow?.makeKey()
                        self.nsWindow?.styleMask.remove(.titled)
                    }
                    .font(sharedFont)
                    .background(color)
                    .scrollContentBackground(.hidden)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text($item.text.wrappedValue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // Allow multiple lines in display mode
                    .background(color)
                    .font(sharedFont)
                    .padding([.horizontal], 5)
                    .overlay(DraggableArea(isEditing: $isEditing))
                    .contextMenu {
                        Button {
                            AppState.shared.copyToClipboard(item)
                        } label: {
                            Label("Copy to clipboard", systemImage: "copy")
                        }
                        Divider()
                        Menu("Change color") {
                            ColorMenu(color: $color, item: item)
                        }
                        Button {
                            showConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "delete")
                        }
                    }
            }
        }
        .confirmationDialog(
            #"Are you sure you want to delete "\#(item.text.truncate(15))"?"#,
            isPresented: $showConfirmation
        ) {
            Button {
                AppState.shared.deleteNote(self.item)
            } label: {
                Text("Delete")
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(color)
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(
            WindowAccessor { window in
                self.nsWindow = window
                window?.styleMask.remove(.titled)
                window?.backgroundColor = NSColor(self.color)
                window?.delegate = self.windowTracker
            }
        )
        .onChange(of: color){ _, newValue in
            self.nsWindow?.backgroundColor = NSColor(self.color)
        }
    }

    func processNote() {
        if $item.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.item)
        }
    }
}

struct ColorMenu: View {
    @Binding var color: Color
    var item: Item

    var body: some View {
        HStack {

            ForEach(NoteColors.allCases.map { $0.rawValue }, id: \.self) { colorName in
                Button {
                    item.color = colorName
                    self.color = Color("Note" + colorName)
                } label: {
                    Image(
                        systemName: item.color == colorName
                            ? "checkmark.square.fill" : "square.fill"
                    )
                    .foregroundStyle(
                        item.color == colorName ? .primary : Color("Note" + colorName), Color("Note" + colorName))

                    Label(colorName, systemImage: "")
                }
            }
        }
    }
}
