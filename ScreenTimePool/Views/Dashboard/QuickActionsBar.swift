import SwiftUI
import FamilyControls
import ManagedSettings

struct QuickActionsBar: View {
    let phase: SessionPhase
    let onStart: () -> Void
    let onStop: () -> Void
    let onRequestTime: () -> Void
    let pendingRequests: Int
    var blockedSelection: FamilyActivitySelection?

    var body: some View {
        VStack(spacing: 12) {
            switch phase {
            case .idle:
                actionButton(title: "Start Break", icon: "play.fill", color: .blue, action: onStart)

            case .active:
                actionButton(title: "End Break Early", icon: "stop.fill", color: .orange, action: onStop)

            case .downtime:
                blockedAppsView
                actionButton(title: "Request More Time", icon: "clock.badge.questionmark", color: .purple, action: onRequestTime)

            case .exhausted:
                actionButton(title: "Request More Time", icon: "clock.badge.questionmark", color: .purple, action: onRequestTime)
            }

            if pendingRequests > 0 {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.red)
                    Text("\(pendingRequests) incoming time request\(pendingRequests == 1 ? "" : "s")")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var blockedAppsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps blocked during break")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if let selection = blockedSelection,
               !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                        }
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxHeight: 120)
            } else {
                Text("No apps selected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
