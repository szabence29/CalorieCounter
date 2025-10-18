import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var isSignedIn: Bool = Auth.auth().currentUser != nil
    @State private var authHandle: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            if isSignedIn {
                MainTabBar()
                    .task {
                        // csak egyszer indítsd el betöltésre
                        if !profileStore.isLoaded {
                            await profileStore.start()
                        }
                    }
            } else {
                LoginView()
            }
        }
        .onAppear {
            // Auth state hallgató feliratkozás
            authHandle = Auth.auth().addStateDidChangeListener { _, user in
                let signedIn = (user != nil)
                if signedIn && !isSignedIn {
                    // friss login → profil betöltés
                    Task { await profileStore.start() }
                }
                isSignedIn = signedIn
            }
        }
        .onDisappear {
            // Hallgató leiratkozás
            if let h = authHandle {
                Auth.auth().removeStateDidChangeListener(h)
                authHandle = nil
            }
        }
    }
}
