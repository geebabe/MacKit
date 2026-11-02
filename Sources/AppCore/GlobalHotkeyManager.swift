// AppCore/GlobalHotkeyManager.swift
// Global system-wide hotkey listener using Carbon EventHotKey APIs.
// Works across macOS without requiring Accessibility or Input Monitoring permissions,
// and consumes the key combination so it does not type into the active application.

import Foundation
import Carbon
import Diagnostics

public enum MacKitHotkeyID: UInt32, CaseIterable, Sendable {
    case clipboardToggle = 1
    case switcherToggle = 2
    case windowSnapLeft = 3
    case windowSnapRight = 4
    case windowMaximize = 5
    case windowRestore = 6
    case windowCenter = 7
}

@MainActor
public final class GlobalHotkeyManager {

    public static let shared = GlobalHotkeyManager()

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private let logger = Logger(category: .appCore)

    public init() {
        installCarbonHandler()
    }

    isolated deinit {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    Task { @MainActor in
                        GlobalHotkeyManager.shared.dispatch(id: hotKeyID.id)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status == noErr {
            logger.info("Carbon global hotkey handler installed successfully")
        } else {
            logger.error("Failed installing Carbon global hotkey handler: \(status)")
        }
    }

    private func dispatch(id: UInt32) {
        if let handler = handlers[id] {
            handler()
        }
    }

    /// Register a global hotkey with a Carbon keyCode and modifier flags.
    @discardableResult
    public func register(
        id: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping @MainActor () -> Void
    ) -> Bool {
        unregister(id: id)

        handlers[id] = action

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x4D4B5430 + (id % 10)),
            id: id
        )

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            hotkeyRefs[id] = ref
            logger.info("Registered global hotkey ID \(id)")
            return true
        } else {
            handlers.removeValue(forKey: id)
            logger.warning("Failed to register global hotkey ID \(id): status \(status)")
            return false
        }
    }

    /// Unregister a specific hotkey.
    public func unregister(id: UInt32) {
        if let ref = hotkeyRefs[id] {
            UnregisterEventHotKey(ref)
            hotkeyRefs.removeValue(forKey: id)
        }
        handlers.removeValue(forKey: id)
    }

    /// Unregister all active hotkeys.
    public func unregisterAll() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        handlers.removeAll()
        logger.info("Unregistered all global hotkeys")
    }
}
