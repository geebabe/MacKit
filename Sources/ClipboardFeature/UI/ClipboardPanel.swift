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

    public let viewModel = ClipboardHistoryViewModel()
    private let logger = Logger(category: .clipboard)

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
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

        setupContent()
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    /// Update the items list from the module.
    public func updateItems(_ newItems: [ClipboardItem]) {
        viewModel.updateItems(newItems)
    }

    public func setStatusBanner(_ message: String?) {
        viewModel.statusBanner = message
    }

    /// Present the panel centered on the active display.
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

    /// Dismiss the panel.
    public func dismiss() {
        orderOut(nil)
        viewModel.searchQuery = ""
        viewModel.statusBanner = nil
        onDismiss?()
    }

    // MARK: - Keyboard Event Handling

    override public func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Command + 1..9 quick paste
        if flags == .command {
            if let index = numberKeyIndex(for: event.keyCode) {
                if viewModel.filteredItems.indices.contains(index) {
                    let item = viewModel.filteredItems[index]
                    onSelectAndPaste?(item)
                    return
                }
            }
        }

        switch event.keyCode {
        case 53: // Escape
            dismiss()

        case 126: // Up Arrow
            viewModel.selectPrevious()

        case 125: // Down Arrow
            viewModel.selectNext()

        case 36: // Enter / Return
            if let item = viewModel.selectedItem {
                onSelectAndPaste?(item)
            }

        case 35: // 'P' key to pin/unpin (when not in search field)
            if flags.isEmpty, let item = viewModel.selectedItem {
                onTogglePin?(item)
                viewModel.applyFilters()
            } else {
                super.keyDown(with: event)
            }

        case 51: // Backspace / Delete
            if flags.contains(.command), let item = viewModel.selectedItem {
                onDelete?(item)
            } else {
                super.keyDown(with: event)
            }

        default:
            super.keyDown(with: event)
        }
    }

    private func numberKeyIndex(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 0 // '1'
        case 19: return 1 // '2'
        case 20: return 2 // '3'
        case 21: return 3 // '4'
        case 23: return 4 // '5'
        case 22: return 5 // '6'
        case 26: return 6 // '7'
        case 28: return 7 // '8'
        case 25: return 8 // '9'
        default: return nil
        }
    }

    // MARK: - Private Setup

    private func setupContent() {
        let view = ClipboardHistoryView(
            viewModel: viewModel,
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

        let hosting = NSHostingView(rootView: view)
        self.contentView = hosting
    }
}
