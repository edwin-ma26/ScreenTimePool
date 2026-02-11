import SwiftUI

struct WelcomeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("ScreenTimePool")
                    .font(.largeTitle.bold())

                Text("Take control of your screen time with daily pools, sessions, and friend accountability.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                featureRow(icon: "timer", title: "Daily Pool", description: "Set a daily budget of screen time")
                featureRow(icon: "play.circle", title: "Sessions", description: "Use time in focused sessions with breaks")
                featureRow(icon: "person.2", title: "Friends", description: "Request more time from friends")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: { viewModel.nextStep() }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
