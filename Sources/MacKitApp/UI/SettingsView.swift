// MacKitApp/UI/SettingsView.swift
// Main settings window — tabbed interface.

import SwiftUI
import AppCore
import Diagnostics

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ClipboardSettingsTab()
                .tabItem {
                    Label("Clipboard", systemImage: "clipboard")
                }

            WindowSettingsTab()
                .tabItem {
                    Label("Windows", systemImage: "macwindow.on.rectangle")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            PermissionsSettingsTab()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(minWidth: 540, minHeight: 400)
    }
}

