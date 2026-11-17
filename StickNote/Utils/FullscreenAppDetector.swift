import AppKit
import CoreGraphics

enum FullscreenAppDetector {
    /// Screens where the frontmost app (other than StickNote) has a layer-0 window covering the display.
    static func screensWithActiveFullscreenApp() -> [NSScreen] {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return [] }
        let frontPID = frontApp.processIdentifier
        let ourPID = ProcessInfo.processInfo.processIdentifier
        if frontPID == ourPID { return [] }
        return screensWithFullscreenWindow(forPID: frontPID)
    }

    private static func screensWithFullscreenWindow(forPID pid: pid_t) -> [NSScreen] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height
        else {
            return []
        }

        var matched: [NSScreen] = []
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
                if matched.contains(where: { $0 === screen }) { continue }
                let frame = screen.frame
                // Fullscreen windows may stop below the camera notch.
                let minHeight = frame.height - screen.safeAreaInsets.top - 2
                if abs(bounds.minX - frame.minX) < 2, abs(bounds.width - frame.width) < 2,
                   abs(bounds.minY - frame.minY) < 2, bounds.height >= minHeight
                {
                    matched.append(screen)
                }
            }
        }
        return matched
    }
}
