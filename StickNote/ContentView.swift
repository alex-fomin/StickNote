import SwiftUI
import AppKit

struct ContentView: View {
    @State private var isEditing: Bool = true
    @State private var text: String = ""
    @FocusState private var isTextEditorFocused: Bool // Track focus on the TextEditor
    private let sharedFont: Font = .system(size: 16, weight: .regular, design: .default) // Shared font

    
    @Environment(\.dismiss) private var dismiss
    
    
    var body: some View {
        ZStack {
            if isEditing {
                TextEditor(text: $text)
                    .focused($isTextEditorFocused) // Bind focus state
                    .onAppear {
                        isTextEditorFocused = true // Automatically focus
                    }
                    .font(sharedFont)
                    .background(Color("#feff9c"))
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
            } else {
                Text(text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Allow multiple lines in display mode
                    .background(Color("#feff9c"))
                    .font(sharedFont)
                    .padding(3)
                    .overlay(DraggableArea(isEditing: $isEditing)) // Enable window dragging
            }
        }
        .background(Color("#feff9c"))
        
        .background(WindowClickOutsideListener(isEditing: $isEditing))
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
