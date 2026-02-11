import SwiftUI

struct FamilyControlsAuthView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Screen Time Access")
                    .font(.title2.bold())

                Text("ScreenTimePool needs permission to manage app access on your device. This allows us to block selected apps during downtime and when your pool is exhausted.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button(action: {
                Task { await viewModel.requestFamilyControlsAuth() }
            }) {
                Text("Authorize")
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { viewModel.previousStep() }
            }
        }
    }
}
