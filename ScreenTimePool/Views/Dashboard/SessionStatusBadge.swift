import SwiftUI

struct SessionStatusBadge: View {
    let phase: SessionPhase

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.subheadline.bold())
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statusText: String {
        switch phase {
        case .idle: return "Ready"
        case .active: return "Session Active"
        case .downtime: return "On Break"
        case .exhausted: return "Pool Exhausted"
        }
    }

    private var statusColor: Color {
        switch phase {
        case .idle: return .green
        case .active: return .blue
        case .downtime: return .orange
        case .exhausted: return .red
        }
    }
}
