// MacKitApp/UI/ShortcutsSettingsTab.swift
// Global shortcuts configuration.
// Milestone 1: Displays current shortcut strings; live editing in Milestone 2.

import SwiftUI
import AppCore

struct ShortcutsSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var shortcutRegistry: ShortcutRegistry

    var body: some View {
        Form {
            if !shortcutRegistry.conflicts.isEmpty {
                Section {
                    ForEach(shortcutRegistry.conflicts, id: \.self) { conflict in
                        Label(conflict, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                } header: {
                    Text("Conflicts")
                }
            }

            Section("Clipboard") {
                ShortcutRow(label: "Open Clipboard History", shortcut: settings.clipboardShortcut)
            }
            .disabled(!settings.clipboardEnabled)

            Section("Window Manager") {
                ShortcutRow(label: "Snap Left", shortcut: settings.snapLeftShortcut)
                ShortcutRow(label: "Snap Right", shortcut: settings.snapRightShortcut)
                ShortcutRow(label: "Maximize", shortcut: settings.maximizeShortcut)
                ShortcutRow(label: "Center", shortcut: settings.centerShortcut)
                ShortcutRow(label: "Restore", shortcut: settings.restoreShortcut)
            }
            .disabled(!settings.windowEnabled)

            Section("Window Switcher") {
                ShortcutRow(label: "Open Window Switcher", shortcut: settings.switcherShortcut)
            }
            .disabled(!settings.switcherEnabled)

            Section {
                Text("Shortcut recording (click to change) is implemented in Milestone 2.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ShortcutRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        LabeledContent(label) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

