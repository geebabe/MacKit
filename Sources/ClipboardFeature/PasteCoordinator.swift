// ClipboardFeature/PasteCoordinator.swift
// Handles restoring items to the system clipboard and pasting into target applications.
// Provides safe fallback when Accessibility permissions are unavailable.

import Foundation
import AppKit
import Carbon.HIToolbox
import SecureStorage
import Diagnostics

/// The result of an attempted paste operation.
public enum PasteResult: Sendable, Equatable {
    case pastedDirectly
    case copiedToClipboardOnly(reason: String)
}

/// Coordinates putting content onto the pasteboard and triggering paste events.
@MainActor
public final class PasteCoordinator {

    private let logger = Logger(category: .clipboard)
    private let pasteboard = NSPasteboard.general

    public init() {}

    /// Restores content to `NSPasteboard.general` and attempts direct paste if permitted.
    public func restoreAndPaste(
        kind: ClipboardItemKind,
        payload: Data,
        onInternalWrite: () -> Void
    ) async -> PasteResult {
        // 1. Notify observer to ignore this write
        onInternalWrite()

        // 2. Put item onto the system pasteboard
        pasteboard.clearContents()
        switch kind {
        case .text, .url:
            if let string = String(data: payload, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
                if kind == .url, let url = URL(string: string) {
                    pasteboard.setString(url.absoluteString, forType: .URL)
                }
            } else {
                return .copiedToClipboardOnly(reason: "Content encoding failed")
            }
        case .image, .screenshot:
            let type: NSPasteboard.PasteboardType = payload.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? .png : .tiff
            pasteboard.setData(payload, forType: type)
        }

        // 3. Attempt direct paste via CGEvent if Accessibility is granted
        if AXIsProcessTrusted() {
            let success = simulateCommandV()
            if success {
                logger.info("Direct paste simulated successfully")
                return .pastedDirectly
            }
        }

        logger.info("Accessibility unavailable or event injection failed — fallback to copy")
        return .copiedToClipboardOnly(reason: "Accessibility permission required for automatic paste")
    }

    /// Simulate Command+V keystroke via CGEvent.
    private func simulateCommandV() -> Bool {
        // Virtual key code for 'V' is 9 (kVK_ANSI_V)
        let vKeyCode: CGKeyCode = 9

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post events to the system event stream
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
