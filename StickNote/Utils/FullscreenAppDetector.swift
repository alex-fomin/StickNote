import AppKit
import CoreGraphics

enum FullscreenAppDetector {
    /// True when the frontmost app (other than StickNote) has a layer-0 window covering a screen frame.
    static func isActiveFullscreenAppPresent() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let frontPID = frontApp.processIdentifier
        let ourPID = ProcessInfo.processInfo.processIdentifier
        if frontPID == ourPID { return false }
        return hasFullscreenWindow(forPID: frontPID)
    }

    private static func hasFullscreenWindow(forPID pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            for info in list {
                guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else {
                    continue
                }
                guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                guard let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha > 0.01 else { continue }
                guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                      let width = bounds["Width"], let height = bounds["Height"],
                      let x = bounds["X"], let y = bounds["Y"]
                else { continue }

                let matchesWidth = abs(width - screenFrame.width) < 2
                let matchesHeight = abs(height - screenFrame.height) < 2
                let matchesOrigin =
                    abs(x - screenFrame.origin.x) < 2 && abs(y - screenFrame.origin.y) < 2
                if matchesWidth && matchesHeight && matchesOrigin {
                    return true
                }
            }
        }
        return false
    }
}
