//
//  NoteHoverToolbarPanelController.swift
//  StickNote
//

import AppKit
import Defaults
import SwiftData
import SwiftUI

private enum NoteHoverToolbarMetrics {
    static let panelHeight: CGFloat = 26
    static let iconFontSize: CGFloat = 9
    static let iconSide: CGFloat = 16
    static let hStackSpacing: CGFloat = 1
}

/// Borderless panel that shows note actions below the note window without resizing the note.
@MainActor
final class NoteHoverToolbarPanelController: NSObject {
    private weak var parentWindow: NSWindow?
    private let hostingView: NSHostingView<AnyView>
    let panel: NSPanel

    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var hideTask: DispatchWorkItem?

    private var isOverNote = false
    private var isOverPanel = false

    private static let hideDelay: TimeInterval = 0.22

    init(
        parentWindow: NSWindow,
        note: Binding<Note>,
        isCollapsed: Binding<Bool>,
        showHideUntilSheet: Binding<Bool>,
        showConfirmation: Binding<Bool>,
        modelContext: ModelContext,
        onDelete: @escaping () -> Void,
        updateWindowSize: @escaping () -> Void
    ) {
        self.parentWindow = parentWindow

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: NoteHoverToolbarMetrics.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = parentWindow.level
        panel.collectionBehavior = parentWindow.collectionBehavior
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        panel.contentView = hosting
        self.hostingView = hosting
        self.panel = panel

        super.init()

        hosting.rootView = AnyView(
            NoteHoverToolbarView(
                note: note,
                isCollapsed: isCollapsed,
                showHideUntilSheet: showHideUntilSheet,
                showConfirmation: showConfirmation,
                onContentChanged: updateWindowSize,
                onDelete: onDelete,
                onPointerInsidePanelChanged: { [weak self] inside in
                    self?.setPointerOverPanel(inside)
                }
            )
            .environment(\.modelContext, modelContext)
        )

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: parentWindow,
            queue: .main
        ) { [weak self] _ in
            self?.repositionIfVisible()
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: parentWindow,
            queue: .main
        ) { [weak self] _ in
            self?.repositionIfVisible()
        }
    }

    func invalidate() {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            self.moveObserver = nil
        }
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        cancelHide()
        panel.orderOut(nil)
        panel.close()
    }

    func setPointerOverNote(_ inside: Bool) {
        isOverNote = inside
        if inside {
            cancelHide()
            reposition()
            panel.orderFront(nil)
        } else {
            scheduleHide()
        }
    }

    private func setPointerOverPanel(_ inside: Bool) {
        isOverPanel = inside
        if inside {
            cancelHide()
            panel.orderFront(nil)
        } else {
            scheduleHide()
        }
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func scheduleHide() {
        cancelHide()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.isOverNote && !self.isOverPanel {
                self.panel.orderOut(nil)
            }
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: task)
    }

    private func repositionIfVisible() {
        guard panel.isVisible else { return }
        reposition()
    }

    func reposition() {
        guard let parent = parentWindow else { return }
        let size = toolbarPanelSize()
        panel.level = parent.level
        syncCollectionBehaviorFromParent()

        let pf = parent.frame
        let gap: CGFloat = 3
        let x = pf.midX - size.width / 2
        let y = pf.minY - gap - size.height
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    /// Width hugs toolbar content; height is fixed.
    private func toolbarPanelSize() -> NSSize {
        hostingView.invalidateIntrinsicContentSize()
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
        var w = hostingView.fittingSize.width
        if !w.isFinite || w < 1 {
            w = 130
        }
        w = ceil(w)
        return NSSize(width: w, height: NoteHoverToolbarMetrics.panelHeight)
    }

    private func syncCollectionBehaviorFromParent() {
        guard let parent = parentWindow else { return }
        panel.collectionBehavior = parent.collectionBehavior
    }
}

// MARK: - Toolbar SwiftUI (hosted in the panel)

struct NoteHoverToolbarView: View {
    @Binding var note: Note
    @Binding var isCollapsed: Bool
    @Binding var showHideUntilSheet: Bool
    @Binding var showConfirmation: Bool
    @Default(.confirmOnDelete) var confirmOnDelete

    var onContentChanged: () -> Void
    var onDelete: () -> Void
    var onPointerInsidePanelChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: NoteHoverToolbarMetrics.hStackSpacing) {
            hoverIconButton(
                systemImage: note.isMarkdown ? "doc.richtext" : "doc.plaintext",
                help: "Markdown"
            ) {
                note.isMarkdown.toggle()
                onContentChanged()
            }

            hoverIconButton(
                systemImage: note.isMinimized
                    ? "arrow.up.left.and.arrow.down.right"
                    : "arrow.down.right.and.arrow.up.left",
                help: note.isMinimized ? "Maximize" : "Minimize"
            ) {
                note.isMinimized.toggle()
                isCollapsed = note.isMinimized
                onContentChanged()
            }

            hoverIconButton(systemImage: "doc.on.doc", help: "Copy to clipboard") {
                AppState.shared.copyToClipboard(note)
            }

            hoverIconButton(systemImage: "square.and.arrow.down", help: "Export to file…") {
                AppState.shared.exportNoteToFile(note)
            }

            hoverIconButton(systemImage: "eye.slash", help: "Hide") {
                AppState.shared.hideNote(note)
            }

            hoverIconButton(systemImage: "trash", help: "Delete") {
                if confirmOnDelete {
                    showConfirmation = true
                } else {
                    onDelete()
                }
            }
            .foregroundStyle(.red)

            Menu {
                LayoutMenu(note: $note)
                Divider()
                Button {
                    note.showOnAllSpaces.toggle()
                    AppState.shared.applyShowOnAllSpaces(note: note)
                } label: {
                    Label(
                        "Show on all spaces",
                        systemImage: note.showOnAllSpaces ? "eye.fill" : "eye"
                    )
                }
                Button {
                    showHideUntilSheet = true
                } label: {
                    Label("Hide note until…", systemImage: "calendar.badge.clock")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: NoteHoverToolbarMetrics.iconFontSize + 1, weight: .semibold))
                    .frame(width: NoteHoverToolbarMetrics.iconSide, height: NoteHoverToolbarMetrics.iconSide)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("More")
        }
        .frame(height: NoteHoverToolbarMetrics.panelHeight)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(.separator.opacity(0.55))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { onPointerInsidePanelChanged($0) }
    }

    private func hoverIconButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: NoteHoverToolbarMetrics.iconFontSize, weight: .medium))
                .frame(width: NoteHoverToolbarMetrics.iconSide, height: NoteHoverToolbarMetrics.iconSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
