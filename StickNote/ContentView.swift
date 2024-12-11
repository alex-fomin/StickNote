import SwiftUI
import AppKit

struct ContentView: View {
    @State private var isEditing: Bool = true
    @State private var text: String = ""
    @FocusState private var isTextEditorFocused: Bool // Track focus on the TextEditor
    private let sharedFont: Font = .system(size: 14, weight: .regular, design: .default) // Shared font
    private let sharedColor: Color = Color(red:254/255,green:255/255,blue:156/255)

    @Environment(\.dismiss) private var dismiss
    @State private var textSize: CGSize = CGSize(width: 100, height: 100)

    var body: some View {
        ZStack {
            if isEditing {
                TextEditor(text: $text)
                    .focused($isTextEditorFocused) // Bind focus state
                    .onAppear {
                        isTextEditorFocused = true // Automatically focus
                    }
                    .font(sharedFont)
                    .background(sharedColor)
                    .scrollContentBackground(.hidden)
                    .onDisappear {
                        if text.isEmpty{
                            dismiss()
                        }
                    }
                    .onSubmit {
                        if text.isEmpty{
                            dismiss()
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Spacer()
                Text(text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Allow multiple lines in display mode
                    .background(sharedColor)
                    .font(sharedFont)
                    .padding([.leading], 5)
                    .padding([.trailing], 5)
                    .overlay(DraggableArea(isEditing: $isEditing))
                Spacer()
            }
        }
        //.frame(maxWidth: .infinity, maxHeight: .infinity) // Make the content expand
        .background(sharedColor)
        .background(WindowClickOutsideListener(isEditing: $isEditing))
        .overlay(DraggableArea(isEditing: $isEditing)) // Enable window dragging
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
        view.layer?.backgroundColor = NSColor.clear.cgColor // Transparent layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A custom NSView subclass for detecting mouse events to drag the window
class DraggableNSView: NSView {
    var area:DraggableArea?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if (event.clickCount == 2){
            DispatchQueue.main.async {
                self.area?.isEditing = true
            }
        }
        else {
            self.window?.performDrag(with: event) // Allow window dragging
        }
    }
}

#Preview {
    ContentView()
}
