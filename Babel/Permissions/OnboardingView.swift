import SwiftUI

struct OnboardingView: View {
    @State private var tick = 0
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Permission.allCases) { permission in
                        PermissionRow(permission: permission, tick: tick)
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { _ in tick &+= 1 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Welcome to Babel")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            Text("Babel needs a few permissions to capture your voice and insert transcribed text into other apps. Grant them below — macOS will guide you for each.")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            if Permissions.allGranted() {
                Label("All set — hold Right Option to dictate.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Text("You can close this window and come back anytime from the menu bar.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            Spacer()
        }
        .padding(16)
    }
}

private struct PermissionRow: View {
    let permission: Permission
    let tick: Int

    @State private var status: PermissionStatus = .notDetermined

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.title)
                    .font(.headline)
                Text(permission.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button(primaryButtonTitle) {
                        Task { await act() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(status == .granted)

                    if let _ = permission.settingsURL {
                        Button("Open System Settings") {
                            Permissions.openSettings(for: permission)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .onAppear { refresh() }
        .onChange(of: tick) { _, _ in refresh() }
    }

    private var statusBadge: some View {
        Image(systemName: statusSymbol)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(statusColor)
            .frame(width: 28, height: 28)
            .padding(.top, 2)
    }

    private var statusSymbol: String {
        switch status {
        case .granted: "checkmark.seal.fill"
        case .denied: "xmark.seal.fill"
        case .notDetermined: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        }
    }

    private var primaryButtonTitle: String {
        switch status {
        case .granted: "Granted"
        case .denied: "Denied — reopen Settings"
        case .notDetermined: "Grant access"
        }
    }

    private func refresh() {
        status = Permissions.status(for: permission)
    }

    private func act() async {
        if status == .denied {
            Permissions.openSettings(for: permission)
            return
        }
        await Permissions.request(permission)
        refresh()
    }
}
