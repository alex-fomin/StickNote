import SwiftUI

struct ContentView: View {
    @State private var username: String = "Heelo"
    @State private var showText: Bool = false
    
    var body: some View {
        
        if (showText) {
            TextEditor(text:$username)
            
        }
        else {
            Text("Hello")
                .onLongPressGesture {
                    print("tap")
                    showText = true
                }
                .onTapGesture {
                    print("tap")
                    showText = true
                }
                .padding()
        }
        
    }
}

#Preview {
    ContentView()
}
