import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @State var nsWindow: NSWindow?

    init(item: Item, isEditing: Bool = false) {
        self.item = item
        self.isEditing = isEditing
        self.windowTracker = WindowPositiontracker(item: item)
    }

    @State private var isEditing: Bool

    @FocusState private var isTextEditorFocused: Bool  // Track focus on the TextEditor
    private let sharedFont: Font = .system(size: 20, weight: .regular, design: .rounded)  // Shared font
    private var sharedColor = Color(red: 254 / 255, green: 255 / 255, blue: 156 / 255)

    @State private var selection: TextSelection?
    @State private var showConfirmation = false

    @Environment(\.dismiss) private var dismiss

    private var windowTracker: WindowPositiontracker

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

                    .background(sharedColor)
                    .scrollContentBackground(.hidden)
                    .onDisappear { processNote() }
                    .onSubmit { processNote() }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text($item.text.wrappedValue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // Allow multiple lines in display mode
                    .background(sharedColor)
                    .font(sharedFont)
                    .padding([.horizontal], 5)
                    .overlay(DraggableArea(isEditing: $isEditing))
                    .contextMenu {
                        Button {
                            showConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "delete")
                        }
                        Button {
                            AppState.shared.copyToClipboard(item)
                        } label: {
                            Label("Copy to clipboard", systemImage: "copy")
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
            Button("Cancel", role: .cancel) {

            }
        }
        .background(sharedColor)
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .background(
            WindowAccessor { window in
                self.nsWindow = window
                window?.styleMask.remove(.titled)  // Removes the title bar
                window?.backgroundColor = NSColor(self.sharedColor)

                window?.delegate = self.windowTracker
            }
        )
    }

    func processNote() {
        if $item.text.wrappedValue.isEmpty {
            AppState.shared.deleteNote(self.item)
        }
    }
}

/// A helper NSViewRepresentable to listen for global clicks outside the SwiftUI window
struct WindowClickOutsideListener: NSViewRepresentable {
    @Binding var isEditing: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            DispatchQueue.main.async {
                self.isEditing = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

}

/// A helper view that enables dragging the entire window
struct DraggableArea: NSViewRepresentable {
    @Binding var isEditing: Bool

    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        view.area = self
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor  // Transparent layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A custom NSView subclass for detecting mouse events to drag the window
class DraggableNSView: NSView {
    var area: DraggableArea?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        print(event)
        if event.clickCount == 2 {
            DispatchQueue.main.async {
                self.area?.isEditing = true
            }
        } else {
            self.window?.performDrag(with: event)  // Allow window dragging
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // Retrieve the `NSWindow` after the view is added to the hierarchy
            callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowPositiontracker: NSObject, NSWindowDelegate {
    var item: Item
    init(item: Item) {
        self.item = item
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        item.width = window.frame.size.width
        item.height = window.frame.size.height
    }

    // Track when the window is moved
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        item.x = window.frame.origin.x
        item.y = window.frame.origin.y
    }

}
