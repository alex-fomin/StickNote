import AppKit

/// Non-activating help tag–style panel so link hints show while the note window is not key (system ``NSView/toolTip`` does not).
enum NoteHoverTooltipWindow {
    private static var panel: NSPanel?
    private static var effectView: NSVisualEffectView?
    private static var label: NSTextField?
    private static var resignActiveObserver: NSObjectProtocol?

    private static let padding = NSEdgeInsets(top: 3, left: 1, bottom: 3, right: 2)
    private static let gapBelowNote: CGFloat = 2

    static func show(text: String, anchoring noteWindow: NSWindow) {
        DispatchQueue.main.async {
            registerResignActiveObserverIfNeeded()
            let (panel, _, label) = ensurePanelAndLabel()

            let tipFontSize: CGFloat = 9
            let font =
                NSFont.toolTipsFont(ofSize: tipFontSize)
                ?? NSFont.systemFont(ofSize: tipFontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
            let attr = NSAttributedString(string: text, attributes: attributes)
            let nsText = text as NSString
            var labelSize = nsText.size(withAttributes: attributes)
            labelSize.width = ceil(labelSize.width)
            labelSize.height = ceil(labelSize.height)

            let contentWidth = labelSize.width + padding.left + padding.right - 20
            let contentHeight = labelSize.height + padding.top + padding.bottom

            label.attributedStringValue = attr
            label.frame = NSRect(x: padding.left, y: padding.bottom, width: labelSize.width, height: labelSize.height)

            guard let contentView = panel.contentView as? NSVisualEffectView else { return }
            contentView.subviews = [label]
            contentView.setFrameSize(NSSize(width: contentWidth, height: contentHeight))

            let panelSize = NSSize(width: contentWidth, height: contentHeight)
            panel.setContentSize(panelSize)
            panel.level = noteWindow.level

            detachFromParentIfNeeded(panel)

            let origin = originBelowNote(noteWindow: noteWindow, panelSize: panelSize)
            panel.setFrame(NSRect(origin: origin, size: panelSize), display: false)

            noteWindow.addChildWindow(panel, ordered: .below)
            panel.orderFront(nil)
        }
    }

    static func hide() {
        DispatchQueue.main.async {
            guard let p = panel else { return }
            p.parent?.removeChildWindow(p)
            p.orderOut(nil)
        }
    }

    private static func detachFromParentIfNeeded(_ panel: NSPanel) {
        if panel.parent != nil {
            panel.parent?.removeChildWindow(panel)
        }
    }

    private static func ensurePanelAndLabel() -> (NSPanel, NSVisualEffectView, NSTextField) {
        if let p = panel, let e = effectView, let l = label {
            return (p, e, l)
        }
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isExcludedFromWindowsMenu = true
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = true

        let effect = NSVisualEffectView(frame: .zero)
        effect.blendingMode = .behindWindow
        effect.state = .active
        if #available(macOS 11.0, *) {
            effect.material = .toolTip
        } else {
            effect.material = .hudWindow
        }
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 3
        effect.layer?.masksToBounds = true
        p.contentView = effect

        let lab = NSTextField(labelWithString: "")
        lab.isEditable = false
        lab.isSelectable = false
        lab.drawsBackground = false

        Self.panel = p
        Self.effectView = effect
        Self.label = lab
        return (p, effect, lab)
    }

    /// Centered **under** the note window (bottom edge + small gap); clamped to the visible screen.
    private static func originBelowNote(noteWindow: NSWindow, panelSize: NSSize) -> NSPoint {
        let win = noteWindow.frame
        let visible = noteWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var x = win.midX - panelSize.width * 0.5
        var y = win.minY - gapBelowNote - panelSize.height

        x = min(max(visible.minX + 2, x), visible.maxX - panelSize.width - 2)
        y = min(max(visible.minY + 2, y), visible.maxY - panelSize.height - 2)
        return NSPoint(x: x, y: y)
    }

    private static func registerResignActiveObserverIfNeeded() {
        guard resignActiveObserver == nil else { return }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            hide()
        }
    }
}
