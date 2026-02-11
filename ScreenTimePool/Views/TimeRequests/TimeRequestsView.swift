import SwiftUI
import FirebaseFirestore

struct TimeRequestsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedTab = 0
    @State private var incomingRequests: [TimeRequest] = []
    @State private var outgoingRequests: [TimeRequest] = []
    @State private var incomingListener: ListenerRegistration?
    @State private var outgoingListener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("Incoming").tag(0)
                    Text("Outgoing").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedTab == 0 {
                    incomingList
                } else {
                    outgoingList
                }
            }
            .navigationTitle("Time Requests")
            .onAppear { startListening() }
            .onDisappear { stopListening() }
        }
    }

    private var incomingList: some View {
        List {
            if incomingRequests.isEmpty {
                ContentUnavailableView(
                    "No Incoming Requests",
                    systemImage: "clock",
                    description: Text("When friends request time from you, they'll appear here.")
                )
            } else {
                ForEach(incomingRequests) { request in
                    IncomingRequestRow(request: request)
                }
            }
        }
    }

    private var outgoingList: some View {
        List {
            if outgoingRequests.isEmpty {
                ContentUnavailableView(
                    "No Outgoing Requests",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your sent time requests will appear here.")
                )
            } else {
                ForEach(outgoingRequests) { request in
                    OutgoingRequestRow(request: request)
                }
            }
        }
    }

    private func startListening() {
        guard let uid = authService.uid else { return }

        incomingListener = TimeRequestService.shared.listenToIncomingRequests(userId: uid) { requests in
            incomingRequests = requests
        }

        outgoingListener = TimeRequestService.shared.listenToOutgoingRequests(userId: uid) { requests in
            outgoingRequests = requests
        }
    }

    private func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
    }
}
