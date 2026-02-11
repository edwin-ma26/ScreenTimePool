import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Select Apps to Manage")
                    .font(.title2.bold())

                Text("Choose which apps should be blocked during downtime and when your pool runs out.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 16)

            FamilyActivityPicker(selection: $viewModel.familyActivitySelection)
                .padding(.horizontal)

            Button(action: { viewModel.saveAppSelection() }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { viewModel.previousStep() }
            }
        }
    }
}
