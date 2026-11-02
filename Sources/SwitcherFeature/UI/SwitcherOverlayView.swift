// SwitcherFeature/UI/SwitcherOverlayView.swift
// SwiftUI view presenting the list of open windows with live search and keyboard hints.

import SwiftUI
import AppKit

public struct SwitcherOverlayView: View {

    @Binding public var windows: [SwitcherWindowItem]
    @Binding public var selectedIndex: Int
    @Binding public var searchQuery: String

    public var onSelectAndActivate: (SwitcherWindowItem) -> Void
    public var onClose: () -> Void

    public init(
        windows: Binding<[SwitcherWindowItem]>,
        selectedIndex: Binding<Int>,
        searchQuery: Binding<String>,
        onSelectAndActivate: @escaping (SwitcherWindowItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self._windows = windows
        self._selectedIndex = selectedIndex
        self._searchQuery = searchQuery
        self.onSelectAndActivate = onSelectAndActivate
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Bar Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter windows…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            // MARK: - Window List
            if windows.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty ? "No open windows found" : "No matching windows")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(windows.enumerated()), id: \.element.id) { index, item in
                                SwitcherItemRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    onActivate: { onSelectAndActivate(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if windows.indices.contains(newIndex) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(windows[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: - Keyboard Hint Footer
            HStack(spacing: 12) {
                KeyboardBadge(label: "Tab / ↓", desc: "Next")
                KeyboardBadge(label: "⇧Tab / ↑", desc: "Prev")
                KeyboardBadge(label: "⏎", desc: "Switch")
                KeyboardBadge(label: "Esc", desc: "Cancel")
                Spacer()
                Text("\(windows.count) windows")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 460, height: 380)
    }
}

// MARK: - Row Subview

private struct SwitcherItemRow: View {
    let item: SwitcherWindowItem
    let isSelected: Bool
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(nsImage: appIcon(for: item.processIdentifier))
                .resizable()
                .frame(width: 28, height: 28)

            // Titles
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if item.isMinimized {
                        Text("Minimized")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }

                Text(item.displayTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            onActivate()
        }
    }

    private func appIcon(for pid: pid_t) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
            return icon
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

// MARK: - Badge Subview

private struct KeyboardBadge: View {
    let label: String
    let desc: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.tertiaryLabelColor).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
