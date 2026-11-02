// ClipboardFeature/UI/ClipboardPanel.swift
// AppKit floating panel hosting the clipboard history view.
// Provides keyboard-driven navigation, focus management, and automatic dismissal.

import AppKit
import SwiftUI
import SecureStorage
import Diagnostics

/// Dedicated floating panel for clipboard history.
public final class ClipboardPanel: NSPanel {

    public var onSelectAndPaste: ((ClipboardItem) -> Void)?
    public var onTogglePin: ((ClipboardItem) -> Void)?
    public var onDelete: ((ClipboardItem) -> Void)?
    public var onClearUnpinned: (() -> Void)?
    public var onDismiss: (() -> Void)?

    private var items: [ClipboardItem] = []
    private var filteredItems: [ClipboardItem] = []
    private var searchQuery: String = ""
    private var selectedIndex: Int = 0
    private var statusBanner: String?

    private let search = ClipboardSearch()
    private var hostingView: NSHostingView<AnyView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
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

    /// Update the items list from the module.
    public func updateItems(_ newItems: [ClipboardItem]) {
        self.items = newItems
        applySearch()
    }

    public func setStatusBanner(_ message: String?) {
        self.statusBanner = message
        rebuildContent()
    }

    /// Present the panel centered on the active display.
    public func present() {
        applySearch()
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - frame.width / 2
            let y = screenRect.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dismiss the panel.
    public func dismiss() {
        orderOut(nil)
        searchQuery = ""
        statusBanner = nil
        onDismiss?()
    }

    // MARK: - Keyboard Event Handling

    override public func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            dismiss()

        case 126: // Up Arrow
            if !filteredItems.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
                rebuildContent()
            }

        case 125: // Down Arrow
            if !filteredItems.isEmpty {
                selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
                rebuildContent()
            }

        case 36: // Enter / Return
            if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                let item = filteredItems[selectedIndex]
                onSelectAndPaste?(item)
            }

        case 51: // Backspace / Delete
            if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                let item = filteredItems[selectedIndex]
                onDelete?(item)
            }

        case 35: // 'P' key (toggle pin)
            if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                let item = filteredItems[selectedIndex]
                onTogglePin?(item)
            }

        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Private Content Management

    private func applySearch() {
        filteredItems = search.filter(items: items, query: searchQuery)
        if selectedIndex >= filteredItems.count {
            selectedIndex = max(0, filteredItems.count - 1)
        }
        rebuildContent()
    }

    private func rebuildContent() {
        let selectedID = filteredItems.indices.contains(selectedIndex) ? filteredItems[selectedIndex].id : nil

        let view = ClipboardHistoryView(
            items: Binding(get: { self.filteredItems }, set: { _ in }),
            searchQuery: Binding(
                get: { self.searchQuery },
                set: { [weak self] newQuery in
                    self?.searchQuery = newQuery
                    self?.applySearch()
                }
            ),
            selectedItemID: Binding(
                get: { selectedID },
                set: { [weak self] id in
                    if let id, let idx = self?.filteredItems.firstIndex(where: { $0.id == id }) {
                        self?.selectedIndex = idx
                    }
                }
            ),
            statusBanner: Binding(get: { self.statusBanner }, set: { self.statusBanner = $0 }),
            onSelectAndPaste: { [weak self] item in
                self?.onSelectAndPaste?(item)
            },
            onTogglePin: { [weak self] item in
                self?.onTogglePin?(item)
            },
            onDelete: { [weak self] item in
                self?.onDelete?(item)
            },
            onClearUnpinned: { [weak self] in
                self?.onClearUnpinned?()
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

