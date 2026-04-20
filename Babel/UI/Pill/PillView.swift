import SwiftUI

struct PillView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            AudioReactiveBlob()
                .frame(width: 30, height: 30)
            Text(state.phase.label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 240, height: 48)
        .glassEffect(.regular, in: .capsule)
        .overlay(
            Capsule()
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        .animation(.smooth(duration: 0.22), value: state.phase)
    }

    private var accentColor: Color {
        switch state.phase {
        case .listening: .blue
        case .processing: .orange
        case .inserting: .green
        case .clipboardFallback: .yellow
        case .error: .red
        case .idle: .gray
        }
    }
}

#Preview {
    let s = AppState()
    s.phase = .listening
    return PillView().environment(s).frame(width: 300, height: 80).padding()
}
