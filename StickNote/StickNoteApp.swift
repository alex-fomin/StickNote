//
//  StickNoteApp.swift
//  StickNote
//
//  Created by Alex Fomin on 05/12/2024.
//

import SwiftUI
import SwiftData
import RichTextKit

@main
struct StickNoteApp: App {    
    var body: some Scene {
        MenuBarExtra("Sticknote", systemImage: "note.text") {
            MainMenu()
        }
        
        Settings{
            Text("Settings")
        }
    }
}
