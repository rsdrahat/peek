import SwiftUI

struct TOCSidebar: View {
    let entries: [TOCEntry]
    let onSelect: (TOCEntry) -> Void

    @State private var selection: TOCEntry.ID?
    @State private var pendingG: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if entries.isEmpty {
                        Text("No headings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(entries) { entry in
                            row(entry).id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: selection) { _, new in
                if let new { withAnimation(.easeOut(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) } }
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
        .background(.thinMaterial)
        .focusable(!entries.isEmpty)
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { if selection == nil { selection = entries.first?.id } }
        .onKeyPress(keys: ["j", "k", "g", "G", " ", "o"]) { press in
            handle(key: press.key); return .handled
        }
        .onKeyPress(.return) { activate(); return .handled }
        .onKeyPress(.downArrow) { move(+1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
    }

    private func row(_ entry: TOCEntry) -> some View {
        Button(action: { selection = entry.id; onSelect(entry) }) {
            HStack(spacing: 0) {
                Text(entry.text)
                    .font(entry.level <= 2 ? .callout : .caption)
                    .fontWeight(entry.level == 1 ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.leading, CGFloat(12 + (entry.level - 1) * 12))
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .background(selection == entry.id ? Color.accentColor.opacity(0.22) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func handle(key: KeyEquivalent) {
        let wasPendingG = pendingG
        pendingG = false
        switch key {
        case "j": move(+1)
        case "k": move(-1)
        case "g":
            if wasPendingG { selection = entries.first?.id; activate() }
            else { pendingG = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pendingG = false } }
        case "G": selection = entries.last?.id; activate()
        case " ", "o": activate()
        default: break
        }
    }

    private func move(_ delta: Int) {
        guard !entries.isEmpty else { return }
        let i = entries.firstIndex(where: { $0.id == selection }) ?? -1
        let next = max(0, min(entries.count - 1, i + delta))
        selection = entries[next].id
        activate()
    }

    private func activate() {
        guard let sel = selection, let entry = entries.first(where: { $0.id == sel }) else { return }
        onSelect(entry)
    }
}
