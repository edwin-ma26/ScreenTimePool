import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var uid: String? { currentUser?.uid }
    var email: String? { currentUser?.email }
    var displayName: String? { currentUser?.displayName }

    func signUp(email: String, password: String, displayName: String) async throws {
        error = nil
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        currentUser = Auth.auth().currentUser
    }

    func signIn(email: String, password: String) async throws {
        error = nil
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func deleteAccount() async throws {
        try await currentUser?.delete()
    }
}
