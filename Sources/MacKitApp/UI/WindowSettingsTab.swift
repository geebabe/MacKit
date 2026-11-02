// MacKitApp/UI/WindowSettingsTab.swift
// Window Manager settings.

import SwiftUI
import AppCore

struct WindowSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Window Manager") {
                Toggle("Enable Window Manager", isOn: $settings.windowEnabled)
            }

            Section("Operations") {
                Group {
                    OperationRow(
                        icon: "rectangle.lefthalf.filled",
                        title: "Snap Left",
                        description: "Resize window to the left half of the screen."
                    )
                    OperationRow(
                        icon: "rectangle.righthalf.filled",
                        title: "Snap Right",
                        description: "Resize window to the right half of the screen."
                    )
                    OperationRow(
                        icon: "rectangle.fill",
                        title: "Maximize",
                        description: "Fill the usable screen area."
                    )
                    OperationRow(
                        icon: "rectangle.center.inset.filled",
                        title: "Center",
                        description: "Center window in its current screen."
                    )
                    OperationRow(
                        icon: "arrow.uturn.backward.circle",
                        title: "Restore",
                        description: "Return window to its frame before the last operation."
                    )
                }
            }
            .disabled(!settings.windowEnabled)

            Section("Notes") {
                Text("Keyboard shortcuts for window operations are configured in the Shortcuts tab.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Window operations require Accessibility permission.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct OperationRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

