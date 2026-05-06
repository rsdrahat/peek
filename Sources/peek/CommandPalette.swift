import SwiftUI

/// A keyboard-driven file/command palette that overlays the main window.
/// This is the v0.4 search shell: query field + results list + nav.
/// The actual search providers (fuzzy file names, content search) plug in
/// by supplying `items` and reacting to `onActivate` — they live in
/// follow-up PRs (search.fuzzy-files, search.content-search).
struct CommandPalette: View {
    @Binding var visible: Bool
    @Binding var query: String
    let items: [PaletteItem]
    let placeholder: String
    let emptyMessage: String?
    let modeLabel: String
    let onActivate: (PaletteItem) -> Void
    let onModeToggle: () -> Void

    @State private var selectedIndex: Int = 0
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            queryField
            if items.isEmpty {
                emptyState
            } else {
                resultList
            }
        }
        .frame(maxWidth: 640)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        .padding(.top, 64)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            // Click anywhere outside the panel to dismiss.
            Color.black.opacity(0.001)
                .onTapGesture { dismiss() }
        )
        .onAppear {
            selectedIndex = 0
            queryFocused = true
        }
        .onChange(of: items) { _, _ in
            // New result set → reset to first item so Return is predictable.
            selectedIndex = 0
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.return) { activateSelected(); return .handled }
        .onKeyPress(.downArrow) { move(+1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.tab) { onModeToggle(); return .handled }
        .onKeyPress(keys: ["n"], phases: .down) { press in
            // Vim-style next, only when Ctrl is held (so it doesn't eat
            // typed letters in the query field).
            guard press.modifiers.contains(.control) else { return .ignored }
            move(+1); return .handled
        }
        .onKeyPress(keys: ["p"], phases: .down) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            move(-1); return .handled
        }
    }

    private var queryField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.callout)
            modeBadge
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($queryFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var modeBadge: some View {
        Button(action: onModeToggle) {
            HStack(spacing: 3) {
                Text(modeLabel)
                    .font(.caption.weight(.medium))
                Text("⇥")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help("Switch mode (Tab)")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            if let msg = emptyMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .opacity(emptyMessage == nil ? 0 : 1)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider()
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ResultRow(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                onActivate(item)
                                dismiss()
                            }
                    }
                }
            }
            .frame(maxHeight: 360)
            .onChange(of: selectedIndex) { _, new in
                withAnimation(.easeOut(duration: 0.06)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func dismiss() {
        visible = false
    }

    private func activateSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        onActivate(items[selectedIndex])
        dismiss()
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        let next = selectedIndex + delta
        selectedIndex = max(0, min(items.count - 1, next))
    }
}

/// One row in the palette's result list. `id` must be stable across queries
/// for SwiftUI to diff correctly.
struct PaletteItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String

    init(id: String, title: String, subtitle: String? = nil, systemImage: String = "doc.text") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

private struct ResultRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.callout)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.18) : .clear)
    }
}
