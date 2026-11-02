// ClipboardFeature/UI/ClipboardHistoryView.swift
// SwiftUI view presenting searchable clipboard history with keyboard navigation.

import SwiftUI
import SecureStorage

public struct ClipboardHistoryView: View {

    @Binding public var items: [ClipboardItem]
    @Binding public var searchQuery: String
    @Binding public var selectedItemID: UUID?
    @Binding public var statusBanner: String?

    public var onSelectAndPaste: (ClipboardItem) -> Void
    public var onTogglePin: (ClipboardItem) -> Void
    public var onDelete: (ClipboardItem) -> Void
    public var onClearUnpinned: () -> Void
    public var onClose: () -> Void

    public init(
        items: Binding<[ClipboardItem]>,
        searchQuery: Binding<String>,
        selectedItemID: Binding<UUID?>,
        statusBanner: Binding<String?>,
        onSelectAndPaste: @escaping (ClipboardItem) -> Void,
        onTogglePin: @escaping (ClipboardItem) -> Void,
        onDelete: @escaping (ClipboardItem) -> Void,
        onClearUnpinned: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._items = items
        self._searchQuery = searchQuery
        self._selectedItemID = selectedItemID
        self._statusBanner = statusBanner
        self.onSelectAndPaste = onSelectAndPaste
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onClearUnpinned = onClearUnpinned
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Bar Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Clear Unpinned", action: onClearUnpinned)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .disabled(items.filter { !$0.isPinned }.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            // MARK: - Status Banner (if copy fallback or notification)
            if let banner = statusBanner {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(banner)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                Divider()
            }

            // MARK: - Items List
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty ? "No clipboard history yet" : "No matches found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchQuery.isEmpty ? "Copy text or images to begin recording." : "Try a different search term.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(items) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isSelected: selectedItemID == item.id,
                                    onPaste: { onSelectAndPaste(item) },
                                    onPin: { onTogglePin(item) },
                                    onDelete: { onDelete(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                    }
                    .onChange(of: selectedItemID) { _, newID in
                        if let newID {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: - Keyboard Hint Footer
            HStack(spacing: 12) {
                KeyboardBadge(label: "⏎", desc: "Paste")
                KeyboardBadge(label: "P", desc: "Pin")
                KeyboardBadge(label: "⌫", desc: "Delete")
                KeyboardBadge(label: "Esc", desc: "Close")
                Spacer()
                Text("\(items.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 440, height: 420)
    }
}

// MARK: - Row Subview

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.systemImageName)
                .font(.system(size: 14))
                .foregroundStyle(item.isPinned ? Color.orange : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(formattedDate(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formattedSize(item.payloadSizeBytes))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin entry" : "Pin entry")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete entry")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            onPaste()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
