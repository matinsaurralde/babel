import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 6)
            modePicker
            Divider().padding(.vertical, 6)
            actions
        }
        .padding(10)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("Babel").font(.system(.headline, design: .rounded))
                Text(state.phase.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MODE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            ForEach(BabelMode.allCases) { mode in
                ModeRow(mode: mode, isSelected: state.mode == mode) {
                    state.mode = mode
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            MenuButton(title: "History…", systemImage: "clock.arrow.circlepath") {
                openWindow(id: BabelWindows.historyID)
                NSApp.activate(ignoringOtherApps: true)
            }
            MenuButton(title: "Settings…", systemImage: "gearshape") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider().padding(.vertical, 4)
            MenuButton(title: "Quit Babel", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
    }
}

private struct ModeRow: View {
    let mode: BabelMode
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: mode.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.displayName)
                        .font(.system(.body, weight: .medium))
                    Text(mode.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovered ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 22)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovered ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
