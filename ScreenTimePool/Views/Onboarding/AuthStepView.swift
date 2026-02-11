import SwiftUI

struct AuthStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                    .font(.title.bold())
                    .padding(.top, 32)

                VStack(spacing: 16) {
                    if viewModel.isSignUp {
                        TextField("Display Name", text: $viewModel.displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(viewModel.isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal, 24)

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                Button(action: {
                    Task { await viewModel.authenticate() }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(viewModel.isSignUp ? "Sign Up" : "Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(viewModel.isLoading || !isFormValid)
                .padding(.horizontal, 24)

                Button(action: { viewModel.isSignUp.toggle() }) {
                    Text(viewModel.isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { viewModel.previousStep() }
            }
        }
    }

    private var isFormValid: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty &&
        (!viewModel.isSignUp || !viewModel.displayName.isEmpty)
    }
}
