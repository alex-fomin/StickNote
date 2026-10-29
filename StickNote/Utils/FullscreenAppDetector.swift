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
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height
        else {
            return false
        }

        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha > 0.01 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict)
            else { continue }

            // CG bounds are top-left based on the primary screen; NSScreen frames are bottom-left based.
            let bounds = CGRect(
                x: cgBounds.minX, y: primaryHeight - cgBounds.maxY,
                width: cgBounds.width, height: cgBounds.height)

            for screen in NSScreen.screens {
                let frame = screen.frame
                // Fullscreen windows may stop below the camera notch.
                let minHeight = frame.height - screen.safeAreaInsets.top - 2
                if abs(bounds.minX - frame.minX) < 2, abs(bounds.width - frame.width) < 2,
                   abs(bounds.minY - frame.minY) < 2, bounds.height >= minHeight
                {
                    return true
                }
            }
        }
        return false
    }
}
