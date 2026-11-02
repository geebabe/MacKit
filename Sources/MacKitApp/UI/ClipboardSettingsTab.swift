// MacKitApp/UI/ClipboardSettingsTab.swift
// Clipboard Manager settings.

import SwiftUI
import AppCore

struct ClipboardSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Enable Clipboard History", isOn: $settings.clipboardEnabled)
                Toggle("Pause Recording", isOn: $settings.clipboardPaused)
                    .disabled(!settings.clipboardEnabled)
            }

            Section("Retention") {
                LabeledContent("Max history entries") {
                    TextField("", value: $settings.clipboardMaxEntries, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .help("Default: 500 unpinned entries. Pinned entries are exempt.")
                }

                LabeledContent("Expire entries after") {
                    HStack {
                        TextField("", value: $settings.clipboardRetentionDays, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("days")
                            .foregroundStyle(.secondary)
                    }
                    .help("Unpinned entries older than this are removed. 0 = no expiry.")
                }
            }

            Section("Excluded Applications") {
                if settings.clipboardExcludedBundleIDs.isEmpty {
                    Text("No applications excluded.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(Array(settings.clipboardExcludedBundleIDs).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Remove") {
                                settings.clipboardExcludedBundleIDs.remove(bundleID)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Text("Clipboard changes from excluded apps will not be recorded.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Limits") {
                LabeledContent("Max text size") {
                    Text("10 MiB")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Max image size") {
                    Text("25 MiB")
                        .foregroundStyle(.secondary)
                }
                Text("Items exceeding these limits are skipped with a visible notification.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

