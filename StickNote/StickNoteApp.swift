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
    init(){
        NoteService.shared = NoteService()
        NoteService.shared?.openAllNotes()
    }
    var body: some Scene {
        MenuBarExtra("Sticknote", systemImage: "note.text") {
            MainMenu()
        }
        
        Settings{
            Text("Settings")
        }
    }
}

import Foundation
import SwiftData

@Model
final class Item:Identifiable {
    var id: UUID = UUID()
    var x: CGFloat?
    var y: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
    var text: String = ""
    
    init(x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil, text: String="") {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
    }
}
