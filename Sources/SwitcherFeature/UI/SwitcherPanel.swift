// SwitcherFeature/UI/SwitcherPanel.swift
// AppKit floating panel hosting the window switcher overlay with keyboard navigation.

import AppKit
import SwiftUI
import Diagnostics

/// Dedicated floating panel for the Window Switcher.
public final class SwitcherPanel: NSPanel {

    public var onSelectAndActivate: ((SwitcherWindowItem) -> Void)?
    public var onDismiss: (() -> Void)?

    private var allWindows: [SwitcherWindowItem] = []
    private var filteredWindows: [SwitcherWindowItem] = []
    private var selectedIndex: Int = 0
    private var searchQuery: String = ""

    private var hostingView: NSHostingView<AnyView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        rebuildContent()
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    /// Update window items and reset selection.
    /// If there are at least 2 windows, default to index 1 (the previously active window).
    public func updateWindows(_ windows: [SwitcherWindowItem]) {
        self.allWindows = windows
        applyFilter()
        if filteredWindows.count > 1 {
            self.selectedIndex = 1
        } else {
            self.selectedIndex = 0
        }
        rebuildContent()
    }

    /// Present the panel centered on screen.
    public func present() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - frame.width / 2
            let y = screenRect.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dismiss the panel without changing focus.
    public func dismiss() {
        orderOut(nil)
        searchQuery = ""
        onDismiss?()
    }

    // MARK: - Keyboard Handling

    override public func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            dismiss()

        case 48: // Tab
            if !filteredWindows.isEmpty {
                let shift = event.modifierFlags.contains(.shift)
                if shift {
                    selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
                } else {
                    selectedIndex = (selectedIndex + 1) % filteredWindows.count
                }
                rebuildContent()
            }

        case 126: // Up Arrow
            if !filteredWindows.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
                rebuildContent()
            }

        case 125: // Down Arrow
            if !filteredWindows.isEmpty {
                selectedIndex = min(filteredWindows.count - 1, selectedIndex + 1)
                rebuildContent()
            }

        case 36: // Enter / Return
            if !filteredWindows.isEmpty && selectedIndex < filteredWindows.count {
                let item = filteredWindows[selectedIndex]
                dismiss()
                onSelectAndActivate?(item)
            }

        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Filtering & Rebuild

    private func applyFilter() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            filteredWindows = allWindows
        } else {
            filteredWindows = allWindows.filter {
                $0.appName.lowercased().contains(trimmed) ||
                $0.windowTitle.lowercased().contains(trimmed)
            }
        }

        if selectedIndex >= filteredWindows.count {
            selectedIndex = max(0, filteredWindows.count - 1)
        }
    }

    private func rebuildContent() {
        let view = SwitcherOverlayView(
            windows: Binding(get: { self.filteredWindows }, set: { _ in }),
            selectedIndex: Binding(get: { self.selectedIndex }, set: { self.selectedIndex = $0 }),
            searchQuery: Binding(
                get: { self.searchQuery },
                set: { [weak self] query in
                    self?.searchQuery = query
                    self?.applyFilter()
                    self?.rebuildContent()
                }
            ),
            onSelectAndActivate: { [weak self] item in
                self?.dismiss()
                self?.onSelectAndActivate?(item)
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingView(rootView: AnyView(view))
        self.contentView = hosting
        self.hostingView = hosting
    }
}
