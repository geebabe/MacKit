// MacKitApp/MacKitApp.swift
// Application entry point.
// Uses NSApplicationDelegate via AppDelegate for menu bar (NSStatusItem),
// and SwiftUI Settings scene for the settings window.

import SwiftUI
import AppKit
import AppCore
import ClipboardFeature
import WindowFeature
import SwitcherFeature
import SecureStorage
import Diagnostics

@main
struct MacKitApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The Settings window — shown via the menu bar.
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.permissionMonitor)
                .environmentObject(appDelegate.shortcutRegistry)
                .environmentObject(appDelegate.launchAtLogin)
        }
    }
}

