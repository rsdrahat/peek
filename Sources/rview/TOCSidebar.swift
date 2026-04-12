import SwiftUI

struct TOCSidebar: View {
    let entries: [TOCEntry]
    let onSelect: (TOCEntry) -> Void

    var body: some View {
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
                        Button(action: { onSelect(entry) }) {
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
        .background(.thinMaterial)
    }
}
