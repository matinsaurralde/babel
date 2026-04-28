import SwiftUI

/// Audio-reactive "plasma" blob. A radial gradient pulses with `AppState.audioLevel`,
/// hue and speed shift with the session phase. Entirely SwiftUI Canvas — no Metal yet.
struct AudioReactiveBlob: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) / 2 - 2
                let t = ctx.date.timeIntervalSinceReferenceDate

                let pulseSpeed = speed(for: state.phase)
                let pulse = 0.88 + 0.12 * sin(t * pulseSpeed)
                let levelBoost = CGFloat(state.audioLevel) * baseRadius * 0.35
                let r = baseRadius * CGFloat(pulse) + levelBoost

                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                let gradient = Gradient(colors: colors(for: state.phase, time: t))

                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: r
                    )
                )

                // Subtle inner highlight that rotates
                let hlAngle = t.truncatingRemainder(dividingBy: .pi * 2)
                let hlOffset = CGSize(
                    width: cos(hlAngle) * r * 0.35,
                    height: sin(hlAngle) * r * 0.35
                )
                let hlCenter = CGPoint(
                    x: center.x + hlOffset.width,
                    y: center.y + hlOffset.height
                )
                let hlRect = CGRect(
                    x: hlCenter.x - r * 0.35,
                    y: hlCenter.y - r * 0.35,
                    width: r * 0.7,
                    height: r * 0.7
                )
                context.fill(
                    Path(ellipseIn: hlRect),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.45), .white.opacity(0)]),
                        center: hlCenter,
                        startRadius: 0,
                        endRadius: r * 0.35
                    )
                )
            }
        }
        .compositingGroup()
        .clipShape(Circle())
    }

    private func speed(for phase: SessionPhase) -> Double {
        switch phase {
        case .listening: 4.0
        case .processing: 10.0
        case .polishing: 8.0
        case .inserting: 7.0
        case .clipboardFallback: 3.0
        case .error: 3.0
        case .idle: 2.5
        }
    }

    private func colors(for phase: SessionPhase, time: Double) -> [Color] {
        switch phase {
        case .listening:
            return [Color(red: 0.55, green: 0.45, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 1.0), .clear]
        case .processing:
            return [Color(red: 1.0, green: 0.6, blue: 0.3), Color(red: 0.95, green: 0.3, blue: 0.6), .clear]
        case .polishing:
            return [Color(red: 0.75, green: 0.45, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.95), .clear]
        case .inserting:
            return [Color(red: 0.4, green: 0.95, blue: 0.6), Color(red: 0.2, green: 0.75, blue: 0.8), .clear]
        case .clipboardFallback:
            return [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.95, green: 0.6, blue: 0.2), .clear]
        case .error:
            return [Color(red: 1.0, green: 0.35, blue: 0.35), Color(red: 0.8, green: 0.1, blue: 0.2), .clear]
        case .idle:
            return [Color.gray.opacity(0.35), .clear]
        }
    }
}
