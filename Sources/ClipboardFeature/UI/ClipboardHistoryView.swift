// ClipboardFeature/UI/ClipboardHistoryView.swift
// Modern, beautiful SwiftUI view for MacKit's Clipboard History.
// Features a Spotlight/Raycast-grade split-view interface:
// - Left: Fast-browsing list with type badges, quick-paste shortcuts, and search
// - Right: Instant rich preview inspector (full text, code formatting, URL cards, image thumbnails)

import SwiftUI
import AppKit
import SecureStorage

// MARK: - View Model

@MainActor
public final class ClipboardHistoryViewModel: ObservableObject {

    public enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case text = "Text"
        case links = "Links"
        case images = "Images"
        case pinned = "Pinned"

        public var id: String { rawValue }

        public var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .text: return "doc.text"
            case .links: return "link"
            case .images: return "photo"
            case .pinned: return "pin.fill"
            }
        }
    }

    @Published public var items: [ClipboardItem] = []
    @Published public var filteredItems: [ClipboardItem] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedCategory: Category = .all
    @Published public var selectedIndex: Int = 0
    @Published public var statusBanner: String?

    private let search = ClipboardSearch()

    public init() {}

    public var selectedItem: ClipboardItem? {
        guard filteredItems.indices.contains(selectedIndex) else { return nil }
        return filteredItems[selectedIndex]
    }

    public func updateItems(_ newItems: [ClipboardItem]) {
        self.items = newItems
        applyFilters()
    }

    public func applyFilters() {
        // 1. Filter by category
        let categoryFiltered: [ClipboardItem]
        switch selectedCategory {
        case .all:
            categoryFiltered = items
        case .text:
            categoryFiltered = items.filter { $0.kind == .text }
        case .links:
            categoryFiltered = items.filter { $0.kind == .url }
        case .images:
            categoryFiltered = items.filter { $0.kind == .image || $0.kind == .screenshot }
        case .pinned:
            categoryFiltered = items.filter { $0.isPinned }
        }

        // 2. Filter by search query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredItems = categoryFiltered
        } else {
            filteredItems = search.filter(items: categoryFiltered, query: query)
        }

        // 3. Keep selected index valid
        if filteredItems.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= filteredItems.count {
            selectedIndex = filteredItems.count - 1
        }
    }

    public func selectPrevious() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }

    public func selectNext() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
    }

    public func selectIndex(_ index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        selectedIndex = index
    }
}

// MARK: - Main History View

public struct ClipboardHistoryView: View {

    @ObservedObject public var viewModel: ClipboardHistoryViewModel

    public var onSelectAndPaste: (ClipboardItem) -> Void
    public var onTogglePin: (ClipboardItem) -> Void
    public var onDelete: (ClipboardItem) -> Void
    public var onClearUnpinned: () -> Void
    public var onClose: () -> Void

    public init(
        viewModel: ClipboardHistoryViewModel,
        onSelectAndPaste: @escaping (ClipboardItem) -> Void,
        onTogglePin: @escaping (ClipboardItem) -> Void,
        onDelete: @escaping (ClipboardItem) -> Void,
        onClearUnpinned: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSelectAndPaste = onSelectAndPaste
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onClearUnpinned = onClearUnpinned
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header & Search Bar
            headerSection

            Divider()

            // Status banner if present (e.g. paste fallback info)
            if let banner = viewModel.statusBanner {
                statusBannerView(banner)
                Divider()
            }

            // MARK: - Main Split Content
            if viewModel.filteredItems.isEmpty {
                emptyStateView
            } else {
                splitContentView
            }

            Divider()

            // MARK: - Bottom Keyboard Shortcuts Footer
            footerSection
        }
        .frame(width: 760, height: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search history, code, links, text…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.applyFilters()
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        viewModel.applyFilters()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Category filter pills
                HStack(spacing: 4) {
                    ForEach(ClipboardHistoryViewModel.Category.allCases) { category in
                        CategoryPill(
                            category: category,
                            isSelected: viewModel.selectedCategory == category,
                            action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.selectedCategory = category
                                    viewModel.applyFilters()
                                }
                            }
                        )
                    }
                }

                Divider()
                    .frame(height: 16)

                // Clear unpinned button
                Button(action: onClearUnpinned) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all unpinned items")
                .disabled(viewModel.items.filter { !$0.isPinned }.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Split Content View

    private var splitContentView: some View {
        HStack(spacing: 0) {
            // Left List: Master items
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(
                                item: item,
                                index: index,
                                isSelected: viewModel.selectedIndex == index,
                                onSelect: {
                                    viewModel.selectIndex(index)
                                },
                                onPaste: {
                                    onSelectAndPaste(item)
                                },
                                onPin: {
                                    onTogglePin(item)
                                    viewModel.applyFilters()
                                },
                                onDelete: {
                                    onDelete(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(width: 330)
                .onChange(of: viewModel.selectedIndex) { _, newIndex in
                    if viewModel.filteredItems.indices.contains(newIndex) {
                        let id = viewModel.filteredItems[newIndex].id
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }

            // Vertical divider
            Divider()

            // Right Inspector: Rich detailed preview
            if let selected = viewModel.selectedItem {
                ClipboardInspectorView(
                    item: selected,
                    onPaste: { onSelectAndPaste(selected) },
                    onPin: {
                        onTogglePin(selected)
                        viewModel.applyFilters()
                    },
                    onDelete: { onDelete(selected) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Select an item to preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: viewModel.searchQuery.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text(viewModel.searchQuery.isEmpty ? "No clipboard history yet" : "No matching items")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text(viewModel.searchQuery.isEmpty ? "Items you copy in any application will securely appear here." : "Try clearing your search query or switching categories.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Banner

    private func statusBannerView(_ banner: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(banner)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: { viewModel.statusBanner = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12))
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 14) {
            KeyboardBadge(label: "⏎", desc: "Paste")
            KeyboardBadge(label: "P", desc: "Pin")
            KeyboardBadge(label: "⌫", desc: "Delete")
            KeyboardBadge(label: "⌘1-9", desc: "Quick Paste")
            KeyboardBadge(label: "Esc", desc: "Close")

            Spacer()

            Text("\(viewModel.filteredItems.count) of \(viewModel.items.count) clips")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: ClipboardHistoryViewModel.Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 10))
                Text(category.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Item Row Subview

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Quick-paste keyboard hint for first 9 items
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.6))
                    .frame(width: 22, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 22)
            }

            // Kind icon with colored badge
            kindBadge(for: item.kind)

            // Content preview & metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewText)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                HStack(spacing: 6) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    }

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Color.secondary.opacity(0.5))

                    Text(formattedDate(item.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary)
                }
            }

            Spacer()

            // Pin indicator / button
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.yellow : Color.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color.accentColor
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func kindBadge(for kind: ClipboardItemKind) -> some View {
        let (icon, color): (String, Color) = {
            switch kind {
            case .text: return ("doc.text.fill", .blue)
            case .url: return ("link", .teal)
            case .image: return ("photo.fill", .purple)
            case .screenshot: return ("camera.viewfinder", .indigo)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundStyle(isSelected ? Color.white : color)
            .frame(width: 20, height: 20)
            .background(
                isSelected
                    ? Color.white.opacity(0.2)
                    : color.opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Rich Inspector Preview Pane

private struct ClipboardInspectorView: View {
    let item: ClipboardItem
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Type title + action buttons
            HStack(spacing: 8) {
                Image(systemName: item.kind.systemImageName)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)

                Text(kindTitle(item.kind))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button(action: onPin) {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onPaste) {
                    Label("Paste", systemImage: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Metadata info badges (word count, char count, size, app)
            HStack(spacing: 8) {
                if let app = item.sourceAppName {
                    inspectorBadge(label: "Source", value: app, icon: "app.fill")
                }
                inspectorBadge(label: "Size", value: formattedSize(item.payloadSizeBytes), icon: "internaldrive")
                if let text = item.fullText ?? (item.kind == .text ? item.previewText : nil) {
                    let words = text.split(whereSeparator: \.isWhitespace).count
                    inspectorBadge(label: "Words", value: "\(words)", icon: "text.word.spacing")
                    inspectorBadge(label: "Characters", value: "\(text.count)", icon: "character")
                }
            }
            .padding(.horizontal, 14)

            Divider()
                .padding(.horizontal, 14)

            // Main Preview Content Area
            previewBodyView
                .padding(.horizontal, 14)

            Spacer()

            // Inspector Bottom Bar: Exact Timestamp
            HStack {
                Text("Copied \(formattedExactDate(item.createdAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: onDelete) {
                    Label("Delete Entry", systemImage: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.2))
    }

    @ViewBuilder
    private var previewBodyView: some View {
        switch item.kind {
        case .text:
            textPreviewView(item.fullText ?? item.previewText)

        case .url:
            urlPreviewView(item.fullText ?? item.previewText)

        case .image, .screenshot:
            imagePreviewView
        }
    }

    private func textPreviewView(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 12, design: isCodeSnippet(text) ? .monospaced : .default))
                .textSelection(.enabled)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func urlPreviewView(_ urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.system(size: 24))
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(string: urlString)?.host ?? "Web Link")
                        .font(.system(size: 13, weight: .semibold))
                    Text(urlString)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.teal.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let url = URL(string: urlString) {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Label("Open in Browser", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
    }

    private var imagePreviewView: some View {
        VStack(alignment: .center, spacing: 8) {
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Image Snapshot")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(formattedSize(item.payloadSizeBytes))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
    }

    private func inspectorBadge(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func kindTitle(_ kind: ClipboardItemKind) -> String {
        switch kind {
        case .text: return "Plain Text"
        case .url: return "URL Link"
        case .image: return "Image"
        case .screenshot: return "Screenshot"
        }
    }

    private func formattedSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func formattedExactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isCodeSnippet(_ text: String) -> Bool {
        let codeIndicators = ["func ", "let ", "var ", "class ", "struct ", "import ", "const ", "def ", "return ", "if (", "{", "}", "=>"]
        return codeIndicators.contains(where: { text.contains($0) })
    }
}

// MARK: - Keyboard Badge

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
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}
