// MacKitApp/UI/PermissionsSettingsTab.swift
// Permission status display and onboarding guidance.

import SwiftUI
import AppCore
import Diagnostics

struct PermissionsSettingsTab: View {
    @EnvironmentObject private var permissionMonitor: PermissionMonitor
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    permission: .accessibility,
                    status: permissionMonitor.accessibilityStatus,
                    isRequired: settings.windowEnabled || settings.switcherEnabled,
                    onRequest: {
                        permissionMonitor.requestAccessibility()
                    },
                    onOpenSettings: {
                        permissionMonitor.openSystemSettings(for: .accessibility)
                    }
                )
            }

            Section("Privacy Notes") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Clipboard history is stored locally, encrypted at rest.", systemImage: "lock.fill")
                    Label("No data is sent to any external service.", systemImage: "wifi.slash")
                    Label("You can delete all history or pause recording at any time.", systemImage: "trash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Refresh Permission Status") {
                    permissionMonitor.refresh()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct PermissionRow: View {
    let permission: Permission
    let status: PermissionStatus
    let isRequired: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: status.systemImageName)
                    .foregroundStyle(statusColor)
                Text(permission.rawValue)
                    .fontWeight(.medium)
                Spacer()
                Text(status.displayLabel)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                if isRequired && !status.isGranted {
                    Text("Required")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            Text(permission.usageDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !status.isGranted {
                Text(permission.recoveryInstructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()

                HStack {
                    if status == .undetermined {
                        Button("Grant Access") { onRequest() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    Button("Open System Settings") { onOpenSettings() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .undetermined: return .orange
        case .unknown: return .gray
        }
    }
}

