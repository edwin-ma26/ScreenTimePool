import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let timeRemaining: String
    let label: String
    var isOvertime: Bool = false

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 20)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center text
            VStack(spacing: 8) {
                Text(timeRemaining)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }

    private var ringColor: Color {
        if isOvertime {
            return .red
        } else if progress > 0.5 {
            return .blue
        } else if progress > 0.2 {
            return .orange
        } else {
            return .red
        }
    }
}
