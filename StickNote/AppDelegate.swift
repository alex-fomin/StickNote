import AppKit
import Cocoa

let updater = Updater(github: "exelban/stats", url: "https://api.mac-stats.com/release/latest")


class AppDelegate: NSObject, NSApplicationDelegate {
 
    func applicationWillFinishLaunching(_ notification: Notification){
        AppState.shared.openAllNotes()
    }
}
