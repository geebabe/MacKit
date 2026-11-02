// MacKitApp/UI/GeneralSettingsTab.swift
// General settings: module enables, launch at login, diagnostics.

import SwiftUI
import AppCore

struct GeneralSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        Form {
            // MARK: - Module toggles
            Section("Modules") {
                Toggle("Clipboard Manager", isOn: $settings.clipboardEnabled)
                    .help("Record your clipboard history locally. You can pause recording at any time.")

                Toggle("Window Manager", isOn: $settings.windowEnabled)
                    .help("Snap, maximize, center and restore windows using keyboard shortcuts.")

                Toggle("Window Switcher", isOn: $settings.switcherEnabled)
                    .help("Navigate between individual windows using a keyboard-driven interface.")
            }

            // MARK: - Launch at login
            Section("Startup") {
                HStack {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin.isRegistered },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    Spacer()
                    if !launchAtLogin.isRegistered {
                        Text("MacKit will not start automatically")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .help("Start MacKit automatically when you log in.")
            }

            // MARK: - App info
            Section("About") {
                HStack {
                    Text("MacKit")
                        .font(.headline)
                    Spacer()
                    Text("v0.1.0 (Milestone 1)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Text("A privacy-first native macOS productivity toolkit.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

