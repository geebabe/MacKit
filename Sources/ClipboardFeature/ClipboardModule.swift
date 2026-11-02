// ClipboardFeature/ClipboardModule.swift
// Clipboard Manager module coordinator.
// Orchestrates capture, encrypted storage, in-memory search, UI, and pasting.

import Foundation
import AppKit
import AppCore
import SecureStorage
import Diagnostics

/// The operational state of the Clipboard module.
public enum ClipboardModuleState: Equatable, Sendable {
    case idle
    case monitoring
    case paused
    case disabled
    case error(String)

    public var displayDescription: String {
        switch self {
        case .idle: return "Ready"
        case .monitoring: return "Monitoring clipboard"
        case .paused: return "Paused — not recording"
        case .disabled: return "Disabled"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

/// MainActor coordinator for the Clipboard Manager module.
@MainActor
public final class ClipboardModule: ObservableObject {

    @Published public private(set) var state: ClipboardModuleState = .idle
    @Published public private(set) var items: [ClipboardItem] = []

    private let logger = Logger(category: .clipboard)
    private let observer = ClipboardObserver()
    private let pasteCoordinator = PasteCoordinator()
    private lazy var panel = ClipboardPanel()

    private var repository: ClipboardRepository?
    private var settings: AppSettings?

    public init() {}

    /// Start the clipboard module with dependencies.
    public func start(
        settings: AppSettings,
        repository: ClipboardRepository
    ) async {
        self.settings = settings
        self.repository = repository

        guard settings.clipboardEnabled else {
            state = .disabled
            logger.info("ClipboardModule is disabled in settings")
            return
        }

        // Configure panel actions
        setupPanelActions()

        // Load existing history from repository
        await loadInitialHistory()

        // Wire clipboard observer
        observer.onCapture = { [weak self] kind, data, metadata in
            await self?.handleCapturedContent(kind: kind, data: data, metadata: metadata)
        }

        if settings.clipboardPaused {
            state = .paused
            logger.info("ClipboardModule started in paused state")
        } else {
            state = .monitoring
            observer.start(interval: 0.5)
            logger.info("ClipboardModule started and monitoring")
        }
    }

    /// Stop monitoring and release UI.
    public func stop() {
        observer.stop()
        panel.dismiss()
        state = .idle
        logger.info("ClipboardModule stopped")
    }

    /// Toggle visibility of the floating clipboard history panel.
    public func togglePanel() {
        guard state != .disabled else { return }
        if panel.isVisible {
            panel.dismiss()
        } else {
            panel.updateItems(items)
            panel.present()
        }
    }

    public func showPanel() {
        guard state != .disabled else { return }
        panel.updateItems(items)
        panel.present()
    }

    public func hidePanel() {
        panel.dismiss()
    }

    /// Update pause/resume status based on settings change.
    public func updatePauseState(isPaused: Bool) {
        guard state != .disabled else { return }
        if isPaused {
            state = .paused
            logger.info("Clipboard recording paused")
        } else {
            state = .monitoring
            logger.info("Clipboard recording resumed")
        }
    }

    // MARK: - Internal Capture Handler

    private func handleCapturedContent(
        kind: ClipboardItemKind,
        data: Data,
        metadata: EncryptedItemMetadata?
    ) async {
        guard let repository, let settings else { return }
        guard !settings.clipboardPaused else { return }

        do {
            let record = try await repository.saveItem(
                kind: kind,
                payload: data,
                metadata: metadata
            )

            // Enforce retention policy asynchronously
            try await repository.enforceRetention(
                maxEntries: settings.clipboardMaxEntries,
                retentionDays: settings.clipboardRetentionDays
            )

            // Construct in-memory item
            let preview = metadata?.previewText ?? (kind == .image ? "Image" : "Text")
            let fullText = (kind == .text || kind == .url) ? String(data: data, encoding: .utf8) : nil

            let item = ClipboardItem(
                id: record.id,
                kind: kind,
                createdAt: record.createdAt,
                lastUsedAt: record.lastUsedAt,
                isPinned: record.isPinned,
                previewText: preview,
                fullText: fullText,
                imageData: kind == .image ? data : nil,
                sourceAppName: metadata?.sourceAppName,
                payloadSizeBytes: data.count
            )

            // Prepend and trim in-memory cache
            items.insert(item, at: 0)
            if items.count > settings.clipboardMaxEntries * 2 {
                items = Array(items.prefix(settings.clipboardMaxEntries))
            }

            panel.updateItems(items)
            logger.info("Captured and cached new \(kind.rawValue) item")
        } catch {
            logger.error("Failed persisting clipboard item: \(error)")
        }
    }

    // MARK: - Initial History Loading

    private func loadInitialHistory() async {
        guard let repository, let settings else { return }
        do {
            let records = try await repository.fetchItems(limit: settings.clipboardMaxEntries)
            var loadedItems: [ClipboardItem] = []

            for record in records {
                let metadata = try? await repository.fetchMetadata(for: record)
                let preview = metadata?.previewText ?? (record.kind == .image ? "Image" : "Text")

                // For text items, load payload into memory for instantaneous search
                var fullText: String?
                if record.kind == .text || record.kind == .url {
                    if let data = try? await repository.fetchPayload(for: record) {
                        fullText = String(data: data, encoding: .utf8)
                    }
                }

                loadedItems.append(ClipboardItem(
                    id: record.id,
                    kind: record.kind,
                    createdAt: record.createdAt,
                    lastUsedAt: record.lastUsedAt,
                    isPinned: record.isPinned,
                    previewText: preview,
                    fullText: fullText,
                    imageData: nil, // Loaded on-demand for images to bound memory
                    sourceAppName: metadata?.sourceAppName,
                    payloadSizeBytes: record.payloadSizeBytes
                ))
            }

            self.items = loadedItems
            self.panel.updateItems(loadedItems)
            logger.info("Loaded \(loadedItems.count) history items from secure storage")
        } catch {
            logger.error("Failed loading initial clipboard history: \(error)")
        }
    }

    // MARK: - Panel Action Bindings

    private func setupPanelActions() {
        panel.onSelectAndPaste = { [weak self] item in
            Task { @MainActor [weak self] in
                await self?.executePaste(for: item)
            }
        }

        panel.onTogglePin = { [weak self] item in
            Task { @MainActor [weak self] in
                await self?.togglePin(for: item)
            }
        }

        panel.onDelete = { [weak self] item in
            Task { @MainActor [weak self] in
                await self?.deleteItem(for: item)
            }
        }

        panel.onClearUnpinned = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.clearUnpinned()
            }
        }
    }

    private func executePaste(for item: ClipboardItem) async {
        guard let repository else { return }
        do {
            // 1. Fetch decrypted payload
            guard let record = try await repository.fetchItems(limit: 1000).first(where: { $0.id == item.id }) else {
                panel.setStatusBanner("Failed locating stored item")
                return
            }
            let payload = try await repository.fetchPayload(for: record)

            // 2. Hide panel before pasting so focus returns to the target app
            panel.dismiss()

            // 3. Mark last used in storage
            try await repository.markUsed(id: item.id)

            // 4. Perform paste
            let result = await pasteCoordinator.restoreAndPaste(
                kind: item.kind,
                payload: payload,
                onInternalWrite: { [weak self] in
                    self?.observer.setWritingInternally()
                }
            )

            if case .copiedToClipboardOnly(let reason) = result {
                logger.info("Item copied; direct paste unavailable (\(reason))")
            }
        } catch {
            logger.error("Failed restoring item payload: \(error)")
            panel.setStatusBanner("Error restoring content")
        }
    }

    private func togglePin(for item: ClipboardItem) async {
        guard let repository else { return }
        let newPinState = !item.isPinned
        do {
            try await repository.setPinned(id: item.id, isPinned: newPinState)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isPinned = newPinState
            }
            panel.updateItems(items)
            logger.info("Toggled pin state to \(newPinState) for \(item.id)")
        } catch {
            logger.error("Failed toggling pin: \(error)")
        }
    }

    private func deleteItem(for item: ClipboardItem) async {
        guard let repository else { return }
        do {
            try await repository.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
            panel.updateItems(items)
            logger.info("Deleted item \(item.id)")
        } catch {
            logger.error("Failed deleting item: \(error)")
        }
    }

    private func clearUnpinned() async {
        guard let repository else { return }
        do {
            try await repository.clearUnpinned()
            items.removeAll { !$0.isPinned }
            panel.updateItems(items)
            logger.info("Cleared unpinned clipboard history")
        } catch {
            logger.error("Failed clearing unpinned history: \(error)")
        }
    }
}
