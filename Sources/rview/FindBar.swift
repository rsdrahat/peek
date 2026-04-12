import SwiftUI

struct FindBar: View {
    @Binding var query: String
    @Binding var visible: Bool
    var lastResultFound: Bool
    var onNext: () -> Void
    var onPrev: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find in page", text: $query)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { onNext() }
                .onAppear { focused = true }
                .onChange(of: visible) { _, v in if v { focused = true } }

            if !query.isEmpty && !lastResultFound {
                Text("No match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onPrev) { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .disabled(query.isEmpty)
                .keyboardShortcut(.return, modifiers: .shift)

            Button(action: onNext) { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .disabled(query.isEmpty)

            Button(action: { visible = false; query = "" }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .frame(maxWidth: 320)
    }
}
