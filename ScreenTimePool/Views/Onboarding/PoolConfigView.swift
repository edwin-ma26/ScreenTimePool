import SwiftUI

struct PoolConfigView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var expandedPicker: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Configure Your Pool")
                        .font(.title2.bold())

                    Text("Set your daily screen time budget and session parameters.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 16)

                VStack(spacing: 12) {
                    TimePickerRow(
                        title: "Daily Pool",
                        detail: "Total screen time per day",
                        minutes: $viewModel.dailyPoolMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "pool",
                        onTap: { expandedPicker = expandedPicker == "pool" ? nil : "pool" }
                    )

                    TimePickerRow(
                        title: "Session Duration",
                        detail: "Length of each session",
                        minutes: $viewModel.sessionDurationMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "session",
                        onTap: { expandedPicker = expandedPicker == "session" ? nil : "session" }
                    )

                    TimePickerRow(
                        title: "Downtime",
                        detail: "Break between sessions",
                        minutes: $viewModel.downtimeDurationMinutes,
                        maxMinutes: 1380,
                        isExpanded: expandedPicker == "downtime",
                        onTap: { expandedPicker = expandedPicker == "downtime" ? nil : "downtime" }
                    )
                }
                .padding(.horizontal, 24)

                Button(action: {
                    Task {
                        await viewModel.completeOnboarding()
                        hasCompletedOnboarding = true
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Finish Setup")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { viewModel.previousStep() }
            }
        }
    }
}

struct TimePickerRow: View {
    let title: String
    let detail: String
    @Binding var minutes: Int
    let maxMinutes: Int
    let isExpanded: Bool
    let onTap: () -> Void

    private var hours: Int { minutes / 60 }
    private var mins: Int { minutes % 60 }
    private var maxHours: Int { maxMinutes / 60 }

    private var displayText: String {
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h 0m"
        } else {
            return "\(mins)m"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(displayText)
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.blue)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { onTap() } }

            if isExpanded {
                HourMinutePicker(
                    totalMinutes: $minutes,
                    maxHours: maxHours,
                    maxTotalMinutes: maxMinutes
                )
                .frame(height: 150)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HourMinutePicker: View {
    @Binding var totalMinutes: Int
    let maxHours: Int
    let maxTotalMinutes: Int

    @State private var selectedHour: Int = 0
    @State private var selectedMinute: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            if maxHours > 0 {
                Picker("Hours", selection: $selectedHour) {
                    ForEach(0...maxHours, id: \.self) { h in
                        Text("\(h) hr").tag(h)
                    }
                }
                .pickerStyle(.wheel)
            }

            Picker("Minutes", selection: $selectedMinute) {
                ForEach(0...59, id: \.self) { m in
                    Text("\(m) min").tag(m)
                }
            }
            .pickerStyle(.wheel)
        }
        .onAppear {
            selectedHour = totalMinutes / 60
            selectedMinute = totalMinutes % 60
        }
        .onChange(of: selectedHour) { _, _ in updateTotal() }
        .onChange(of: selectedMinute) { _, _ in updateTotal() }
    }

    private func updateTotal() {
        let newTotal = max(1, min(selectedHour * 60 + selectedMinute, maxTotalMinutes))
        totalMinutes = newTotal
        // Sync pickers back if clamped
        let clampedHour = newTotal / 60
        let clampedMinute = newTotal % 60
        if selectedHour != clampedHour { selectedHour = clampedHour }
        if selectedMinute != clampedMinute { selectedMinute = clampedMinute }
    }
}
