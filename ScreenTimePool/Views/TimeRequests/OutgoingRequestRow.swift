import SwiftUI

struct OutgoingRequestRow: View {
    let request: TimeRequest

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("To: \(request.toDisplayName)")
                    .font(.body.bold())

                Text("Requested \(request.requestedMinutes) minutes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let granted = request.grantedMinutes, request.status == "modified" {
                    Text("Granted \(granted) minutes")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(request.status.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch request.status {
        case "pending": return .orange
        case "approved", "modified": return .green
        case "denied": return .red
        case "expired": return .gray
        default: return .secondary
        }
    }
}
