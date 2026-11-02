// ClipboardFeature/ClipboardObserver.swift
// Stateful observer monitoring NSPasteboard changes with privacy safeguards.
// Avoids duplicate captures, respects exclusions, and ignores internal writes.

import Foundation
import AppKit
import AppCore
import SecureStorage
import Diagnostics

/// Observes system pasteboard changes and notifies the coordinator when eligible content appears.
@MainActor
public final class ClipboardObserver {

    public typealias CaptureHandler = @MainActor (ClipboardItemKind, Data, EncryptedItemMetadata?) async -> Void

    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastCapturedHash: Int?
    private var isSelfWriting: Bool = false

    private let filter = ClipboardFilter()
    private let logger = Logger(category: .clipboard)
    private let pasteboard = NSPasteboard.general

    public var onCapture: CaptureHandler?

    public init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    /// Mark that MacKit is performing an internal pasteboard write, so the resulting
    /// change event should not be recorded as a new history item.
    public func setWritingInternally() {
        isSelfWriting = true
    }

    /// Start polling for clipboard changes.
    public func start(interval: TimeInterval = 0.5) {
        stop()
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    /// Stop polling.
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Main polling step executed on each timer tick.
    public func poll(
        isPaused: Bool = false,
        excludedBundleIDs: Set<String> = []
    ) {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // 1. Skip if MacKit itself wrote to pasteboard
        if isSelfWriting {
            isSelfWriting = false
            return
        }

        // 2. Skip if user paused recording
        if isPaused {
            logger.info("Clipboard change detected but recording is paused")
            return
        }

        // 3. Inspect pasteboard items
        guard let items = pasteboard.pasteboardItems, let firstItem = items.first else {
            return
        }

        // 4. Privacy: Check for concealed / transient types (1Password, Bitwarden, etc.)
        if filter.isConcealedOrTransient(types: firstItem.types) {
            logger.info("Ignored concealed/transient pasteboard item")
            return
        }

        // 5. Check originating app exclusion
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName

        if filter.isAppExcluded(bundleID: bundleID, excludedBundleIDs: excludedBundleIDs) {
            logger.info("Ignored clipboard item from excluded app: \(bundleID ?? "unknown")")
            return
        }

        // 6. Extract supported representations
        processPasteboardItem(firstItem, bundleID: bundleID, appName: appName)
    }

    private func processPasteboardItem(_ item: NSPasteboardItem, bundleID: String?, appName: String?) {
        // A. Images (PNG or TIFF)
        if item.types.contains(.png) || item.types.contains(.tiff) {
            if let imgData = item.data(forType: .png) ?? item.data(forType: .tiff) {
                // Size validation
                if case .failure(let reason) = filter.validateImageSize(byteCount: imgData.count) {
                    logger.warning("Rejected clipboard image: \(reason)")
                    return
                }

                // Deduplication
                let hash = imgData.hashValue
                if lastCapturedHash == hash { return }
                lastCapturedHash = hash

                let metadata = EncryptedItemMetadata(
                    previewText: "Image (\(imgData.count / 1024) KB)",
                    sourceBundleID: bundleID,
                    sourceAppName: appName
                )

                Task { @MainActor in
                    await onCapture?(.image, imgData, metadata)
                }
                return
            }
        }

        // B. Plain Text or URL
        if let string = item.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            guard let textData = string.data(using: .utf8) else { return }

            // Size validation
            if case .failure(let reason) = filter.validateTextSize(byteCount: textData.count) {
                logger.warning("Rejected clipboard text: \(reason)")
                return
            }

            // Deduplication
            let hash = string.hashValue
            if lastCapturedHash == hash { return }
            lastCapturedHash = hash

            // Detect whether it's a URL
            let isURL = (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")) && URL(string: trimmed) != nil
            let kind: ClipboardItemKind = isURL ? .url : .text

            let metadata = EncryptedItemMetadata(
                previewText: ClipboardItem.makePreview(from: string),
                sourceBundleID: bundleID,
                sourceAppName: appName
            )

            Task { @MainActor in
                await onCapture?(kind, textData, metadata)
            }
        }
    }
}
